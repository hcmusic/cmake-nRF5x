cmake_minimum_required(VERSION 3.6)
# check if all the necessary tools paths have been provided.
if (NOT NRF5_SDK_PATH)
    message(FATAL_ERROR "The path to the nRF5 SDK (NRF5_SDK_PATH) must be set.")
endif ()

if (NOT NRFJPROG)
    message(FATAL_ERROR "The path to the nrfjprog utility (NRFJPROG) must be set.")
endif ()

set(BLACKMAGIC_DEVICE CACHE STRING "")
if (NOT ${BLACKMAGIC_DEVICE} EQUAL "")
    message(STATUS "Use BlackMagic Probe")
endif()

# convert toolchain path to bin path
if(DEFINED ARM_NONE_EABI_TOOLCHAIN_PATH)
    set(ARM_NONE_EABI_TOOLCHAIN_BIN_PATH ${ARM_NONE_EABI_TOOLCHAIN_PATH}/bin)
endif()

# check if the nRF target has been set
if (NRF_TARGET MATCHES "nrf51")

elseif (NRF_TARGET MATCHES "nrf52")

elseif (NOT NRF_TARGET)
    message(FATAL_ERROR "nRF target must be defined")
else ()
    message(FATAL_ERROR "Only nRF51 and rRF52 boards are supported right now")
endif ()

# must be set in file (not macro) scope (in macro would point to parent CMake directory)
set(DIR_OF_nRF5x_CMAKE ${CMAKE_CURRENT_LIST_DIR})

macro(nRF5x_toolchainSetup)
    include(${DIR_OF_nRF5x_CMAKE}/arm-gcc-toolchain.cmake)
endmacro()

macro(nRF5x_setup)
    if(NOT DEFINED ARM_GCC_TOOLCHAIN)
        message(FATAL_ERROR "The toolchain must be set up before calling this macro")
    endif()
    # fix on macOS: prevent cmake from adding implicit parameters to Xcode
    set(CMAKE_OSX_SYSROOT "/")
    set(CMAKE_OSX_DEPLOYMENT_TARGET "")

    # language standard/version settings
    set(CMAKE_C_STANDARD 99)
    set(CMAKE_CXX_STANDARD 98)

    # CPU specyfic settings
    if (NRF_TARGET MATCHES "nrf51")
        # nRF51 (nRF51-DK => PCA10028)
        if(NOT DEFINED NRF5_LINKER_SCRIPT)
            set(NRF5_LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/gcc_nrf51.ld")
        endif()
        set(CPU_FLAGS "-mcpu=cortex-m0 -mfloat-abi=soft")
        add_definitions(-DBOARD_PCA10028 -DNRF51 -DNRF51422)
        add_definitions(-DS130 -DNRF_SD_BLE_API_VERSION=2 -DSWI_DISABLE0 -DBLE_STACK_SUPPORT_REQD)
        include_directories(
                "${NRF5_SDK_PATH}/components/softdevice/s130/headers"
                "${NRF5_SDK_PATH}/components/softdevice/s130/headers/nrf51"
        )
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/modules/nrfx/mdk/system_nrf51.c"
                "${NRF5_SDK_PATH}/modules/nrfx/mdk/gcc_startup_nrf51.S"
                )
        set(SOFTDEVICE_PATH "${NRF5_SDK_PATH}/components/softdevice/s130/hex/s130_nrf51_2.0.0_softdevice.hex")
    elseif (NRF_TARGET MATCHES "nrf52")
        # nRF52 (nRF52-DK => PCA10040)

        if(NOT DEFINED NRF5_LINKER_SCRIPT)
            set(NRF5_LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/gcc_nrf52.ld")
        endif()
        set(CPU_FLAGS "-mcpu=cortex-m4 -mfloat-abi=hard -mfpu=fpv4-sp-d16")
        add_definitions(-DNRF52 -DNRF52832 -DNRF52832_XXAA -DNRF52_PAN_74 -DNRF52_PAN_64 -DNRF52_PAN_12 -DNRF52_PAN_58 -DNRF52_PAN_54 -DNRF52_PAN_31 -DNRF52_PAN_51 -DNRF52_PAN_36 -DNRF52_PAN_15 -DNRF52_PAN_20 -DNRF52_PAN_55 -DBOARD_PCA10040)
        add_definitions(-DS132 -DBLE_STACK_SUPPORT_REQD -DNRF_SD_BLE_API_VERSION=7)
        include_directories(
                "${NRF5_SDK_PATH}/components/softdevice/s132/headers"
                "${NRF5_SDK_PATH}/components/softdevice/s132/headers/nrf52"
        )
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/modules/nrfx/mdk/system_nrf52.c"
                "${NRF5_SDK_PATH}/modules/nrfx/mdk/gcc_startup_nrf52.S"
                )
        file(GLOB SOFTDEVICE_PATH "${NRF5_SDK_PATH}/components/softdevice/s132/hex/s132_nrf52_*_softdevice.hex")
    endif ()

    set(COMMON_FLAGS "-MP -MD -mthumb -mabi=aapcs -Wall -g3 -ffunction-sections -fdata-sections -fno-strict-aliasing -fno-builtin --short-enums ${CPU_FLAGS}")

    # compiler/assambler/linker flags
    set(CMAKE_C_FLAGS "${COMMON_FLAGS}")
    set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -O0")
    set(CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_RELEASE} -O3")
    set(CMAKE_CXX_FLAGS "${COMMON_FLAGS}")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O0")
    set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3")
    set(CMAKE_ASM_FLAGS "-MP -MD -x assembler-with-cpp")
    set(CMAKE_EXE_LINKER_FLAGS "-mthumb -mabi=aapcs -L ${NRF5_SDK_PATH}/modules/nrfx/mdk -T${NRF5_LINKER_SCRIPT} ${CPU_FLAGS} -Wl,--gc-sections --specs=nano.specs -lc -lnosys -lm")
    # note: we must override the default cmake linker flags so that CMAKE_C_FLAGS are not added implicitly
    set(CMAKE_C_LINK_EXECUTABLE "${CMAKE_C_COMPILER} <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
    set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_C_COMPILER} <LINK_FLAGS> <OBJECTS> -lstdc++ -o <TARGET> <LINK_LIBRARIES>")

    # basic board definitions and drivers
    include_directories(
            "${NRF5_SDK_PATH}/components"
            "${NRF5_SDK_PATH}/components/boards"
            "${NRF5_SDK_PATH}/components/softdevice/common"
            "${NRF5_SDK_PATH}/integration/nrfx"
            "${NRF5_SDK_PATH}/integration/nrfx/legacy"
            "${NRF5_SDK_PATH}/modules/nrfx"
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/include"
            "${NRF5_SDK_PATH}/modules/nrfx/hal"
            "${NRF5_SDK_PATH}/modules/nrfx/mdk"
    )
    option(LIB_UART "include uart" true)
    option(LIB_UARTE "include uart" true)
    option(LIB_GPIOTE "include gpiote" true)
    option(LIB_SDH "include soft device libraries" true)
    option(LIB_DRV_CLOCK "incluce drv clock" true)
    option(LIB_BOARDS "include boards" true)
    option(LIB_PRS "include prs" true)
    option(LIB_FREERTOS "include FreeRTOS" FALSE)

    if(LIB_UART)
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_uart.c"
                "${NRF5_SDK_PATH}/integration/nrfx/legacy/nrf_drv_uart.c"
        )
    endif()
    if(LIB_UARTE)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_uarte.c")
    endif()
    if(LIB_GPIOTE)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_gpiote.c")
    endif()
    if(LIB_SDH)
        list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/softdevice/common/nrf_sdh.c"
            "${NRF5_SDK_PATH}/components/softdevice/common/nrf_sdh_soc.c")
    endif()
    if(LIB_DRV_CLOCK)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/integration/nrfx/legacy/nrf_drv_clock.c")
    endif()
    if(LIB_BOARDS)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/components/boards/boards.c")
    endif()
    if(LIB_PRS)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/prs/nrfx_prs.c")
    endif()

    if(LIB_FREERTOS)
        file(GLOB FREERTOS_SOURCE_FILES "${NRF5_SDK_PATH}/external/freertos/source/*.c")
        list(APPEND SDK_SOURCE_FILES ${FREERTOS_SOURCE_FILES})
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/external/freertos/source/portable/MemMang/heap_4.c")

        if (NRF_TARGET MATCHES "nrf51")
            list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/external/freertos/portable/GCC/nrf51/port.c")
            list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/external/freertos/portable/GCC/nrf51/portmacro.h")
            list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/external/freertos/portable/CMSIS/nrf51/port_cmsis.c")
            list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/external/freertos/portable/CMSIS/nrf51/port_cmsis_systick.c")
            include_directories("${NRF5_SDK_PATH}/external/freertos/portable/GCC/nrf51/")
            include_directories("${NRF5_SDK_PATH}/external/freertos/portable/CMSIS/nrf51/")
        endif()

        if (NRF_TARGET MATCHES "nrf52")
            list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/external/freertos/portable/GCC/nrf52/port.c")
            list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/external/freertos/portable/CMSIS/nrf52/port_cmsis.c")
            list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/external/freertos/portable/CMSIS/nrf52/port_cmsis_systick.c")
            include_directories("${NRF5_SDK_PATH}/external/freertos/portable/GCC/nrf52/")
            include_directories("${NRF5_SDK_PATH}/external/freertos/portable/CMSIS/nrf52/")
        endif()


        include_directories(${NRF5_SDK_PATH}/external/freertos/source/include)
        #include_directories(${NRF5_SDK_PATH}/external/freertos/config)
    endif()
    
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_clock.c"
            "${NRF5_SDK_PATH}/modules/nrfx/soc/nrfx_atomic.c"
            )


    # toolchain specific
    include_directories(
            "${NRF5_SDK_PATH}/components/toolchain/cmsis/include"
    )


    # libraries
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/atomic"
            "${NRF5_SDK_PATH}/components/libraries/atomic_fifo"
            "${NRF5_SDK_PATH}/components/libraries/atomic_flags"
            "${NRF5_SDK_PATH}/components/libraries/balloc"
            "${NRF5_SDK_PATH}/components/libraries/bootloader/ble_dfu"
            "${NRF5_SDK_PATH}/components/libraries/cli"
            "${NRF5_SDK_PATH}/components/libraries/crc16"
            "${NRF5_SDK_PATH}/components/libraries/crc32"
            "${NRF5_SDK_PATH}/components/libraries/crypto"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/cc310_bl"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/cc310"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/mbedtls"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/oberon"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/nrf_sw"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/nrf_hw"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/cifra"
            "${NRF5_SDK_PATH}/external/nrf_oberon"
            "${NRF5_SDK_PATH}/external/nrf_oberon/include"
            "${NRF5_SDK_PATH}/external/mbedtls/include"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/micro_ecc"
            "${NRF5_SDK_PATH}/components/libraries/crypto/backend/optiga"
            "${NRF5_SDK_PATH}/components/libraries/csense"
            "${NRF5_SDK_PATH}/components/libraries/csense_drv"
            "${NRF5_SDK_PATH}/components/libraries/delay"
            "${NRF5_SDK_PATH}/components/libraries/ecc"
            "${NRF5_SDK_PATH}/components/libraries/experimental_section_vars"
            "${NRF5_SDK_PATH}/components/libraries/experimental_task_manager"
            "${NRF5_SDK_PATH}/components/libraries/fds"
            "${NRF5_SDK_PATH}/components/libraries/fstorage"
            "${NRF5_SDK_PATH}/components/libraries/gfx"
            "${NRF5_SDK_PATH}/components/libraries/gpiote"
            "${NRF5_SDK_PATH}/components/libraries/hardfault"
            "${NRF5_SDK_PATH}/components/libraries/hci"
            "${NRF5_SDK_PATH}/components/libraries/led_softblink"
            "${NRF5_SDK_PATH}/components/libraries/log"
            "${NRF5_SDK_PATH}/components/libraries/log/src"
            "${NRF5_SDK_PATH}/components/libraries/low_power_pwm"
            "${NRF5_SDK_PATH}/components/libraries/mem_manager"
            "${NRF5_SDK_PATH}/components/libraries/memobj"
            "${NRF5_SDK_PATH}/components/libraries/mpu"
            "${NRF5_SDK_PATH}/components/libraries/mutex"
            "${NRF5_SDK_PATH}/components/libraries/pwm"
            "${NRF5_SDK_PATH}/components/libraries/pwr_mgmt"
            "${NRF5_SDK_PATH}/components/libraries/queue"
            "${NRF5_SDK_PATH}/components/libraries/ringbuf"
            "${NRF5_SDK_PATH}/components/libraries/scheduler"
            "${NRF5_SDK_PATH}/components/libraries/sdcard"
            "${NRF5_SDK_PATH}/components/libraries/slip"
            "${NRF5_SDK_PATH}/components/libraries/sortlist"
            "${NRF5_SDK_PATH}/components/libraries/spi_mngr"
            "${NRF5_SDK_PATH}/components/libraries/stack_guard"
            "${NRF5_SDK_PATH}/components/libraries/strerror"
            "${NRF5_SDK_PATH}/components/libraries/svc"
            "${NRF5_SDK_PATH}/components/libraries/stack_info"
            "${NRF5_SDK_PATH}/components/libraries/timer"
            "${NRF5_SDK_PATH}/components/libraries/twi_mngr"
            "${NRF5_SDK_PATH}/components/libraries/twi_sensor"
            "${NRF5_SDK_PATH}/components/libraries/usbd"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/audio"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/cdc"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/cdc/acm"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/hid"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/hid/generic"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/hid/kbd"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/hid/mouse"
            "${NRF5_SDK_PATH}/components/libraries/usbd/class/msc"
            "${NRF5_SDK_PATH}/components/libraries/util"
    )

    option(SOFTDEVICE_PRESENT "SoftDevice present in 0x0" true)
    if(SOFTDEVICE_PRESENT)
        add_definitions(-DSOFTDEVICE_PRESENT)
    endif()

    option(LIB_LOGS "include log libraries" true)
    option(LIB_ERROR "include error libraries" true)
    option(LIB_BALLOC "include balloc libraries" true)
    option(LIB_SECTION_ITER "include section_iter libraries" true)
    option(LIB_HARDFAULT_IMPL "include hardfault_implementation libraries" true)
    option(LIB_ASSERT "include assert libraries" true)
    option(LIB_MEMOBJ "include memobj libraries" true)
    option(LIB_PWR_MGMT "include pwr_mgmt libraries" true)
    option(LIB_RINGBUF "include ringbuf libraries" true)
    option(LIB_UART_RETARGET "include uart retarget libraries" true)

    if(LIB_LOGS)
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_backend_flash.c"
                "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_backend_rtt.c"
                "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_backend_serial.c"
                "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_backend_uart.c"
                "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_default_backends.c"
                "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_frontend.c"
                "${NRF5_SDK_PATH}/components/libraries/log/src/nrf_log_str_formatter.c"
        )
    endif()
    if(LIB_ERROR)
        list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/util/app_error.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_error_weak.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_error_handler_gcc.c"
            "${NRF5_SDK_PATH}/components/libraries/strerror/nrf_strerror.c"
        )
    endif()
    if(LIB_BALLOC)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/components/libraries/balloc/nrf_balloc.c")
    endif()
    if(LIB_SECTION_ITER)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/components/libraries/experimental_section_vars/nrf_section_iter.c")
    endif()
    if(LIB_HARDFAULT_IMPL)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/components/libraries/hardfault/hardfault_implementation.c")
    endif()
    if(LIB_ASSERT)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/components/libraries/util/nrf_assert.c")
    endif()
    if(LIB_MEMOBJ)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/components/libraries/memobj/nrf_memobj.c")
    endif()
    if(LIB_PWR_MGMT)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/components/libraries/pwr_mgmt/nrf_pwr_mgmt.c")
    endif()
    if(LIB_RINGBUF)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/components/libraries/ringbuf/nrf_ringbuf.c")
    endif()
    if(LIB_UART_RETARGET)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/components/libraries/uart/retarget.c")
    endif()
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/atomic/nrf_atomic.c"
            "${NRF5_SDK_PATH}/components/libraries/atomic_fifo/nrf_atfifo.c"
            "${NRF5_SDK_PATH}/components/libraries/atomic_flags/nrf_atflags.c"
            "${NRF5_SDK_PATH}/components/libraries/util/app_util_platform.c"
            "${NRF5_SDK_PATH}/components/libraries/util/sdk_mapped_flags.c"
            )

    # Segger RTT
    include_directories(
            "${NRF5_SDK_PATH}/external/segger_rtt/"
    )
    option(LIB_SEGGER_RTT "include segger_rtt library" true)
    if(LIB_SEGGER_RTT)
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/external/segger_rtt/SEGGER_RTT_Syscalls_GCC.c"
                "${NRF5_SDK_PATH}/external/segger_rtt/SEGGER_RTT.c"
                "${NRF5_SDK_PATH}/external/segger_rtt/SEGGER_RTT_printf.c"
                )
    endif()

    # Other external
    include_directories(
            "${NRF5_SDK_PATH}/external/fprintf/"
            "${NRF5_SDK_PATH}/external/utf_converter/"
    )
    option(LIB_UTF_CONVERTER "include utf_converter" true)
    option(LIB_FPRINTF "include fprintf" true)
    if(LIB_UTF_CONVERTER)
        list(APPEND SDK_SOURCE_FILES "${NRF5_SDK_PATH}/external/utf_converter/utf.c")
    endif()
    if(LIB_FPRINTF)
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/external/fprintf/nrf_fprintf.c"
                "${NRF5_SDK_PATH}/external/fprintf/nrf_fprintf_format.c"
        )
    endif()
    


    # Common Bluetooth Low Energy files
    include_directories(
            "${NRF5_SDK_PATH}/components/ble"
            "${NRF5_SDK_PATH}/components/ble/common"
            "${NRF5_SDK_PATH}/components/ble/ble_advertising"
            "${NRF5_SDK_PATH}/components/ble/ble_dtm"
            "${NRF5_SDK_PATH}/components/ble/ble_link_ctx_manager"
            "${NRF5_SDK_PATH}/components/ble/ble_racp"
            "${NRF5_SDK_PATH}/components/ble/nrf_ble_qwr"
            "${NRF5_SDK_PATH}/components/ble/peer_manager"
    )

    # adds target for erasing and flashing the board with a softdevice
    if(BLACKMAGIC_DEVICE)
    add_custom_target("FLASH_SOFTDEVICE" ALL
    DEPENDS ${EXECUTABLE_NAME}
    COMMAND ${CMAKE_GDB} -ex "set confirm off" -ex "target extended-remote ${BLACKMAGIC_DEVICE}" -ex "monitor swdp_scan" -ex "attach 1" -ex "load ${SOFTDEVICE_PATH}" -ex "quit"
    COMMENT "flashing SoftDevice"
    )
    else()
    add_custom_target(FLASH_SOFTDEVICE ALL
            COMMAND ${NRFJPROG} --program ${SOFTDEVICE_PATH} -f ${NRF_TARGET} --sectorerase
            COMMAND sleep 0.5s
            COMMAND ${NRFJPROG} --reset -f ${NRF_TARGET}
            COMMENT "flashing SoftDevice"
            )
    endif()

    #add_custom_target(FLASH_ERASE ALL
    #        COMMAND ${NRFJPROG} --eraseall -f ${NRF_TARGET}
    #        COMMENT "erasing flashing"
    #        )

    if(${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Darwin")
        set(TERMINAL "open")
    elseif(${CMAKE_HOST_SYSTEM_NAME} STREQUAL "Windows")
        set(TERMINAL "sh")
    else()
        set(TERMINAL "gnome-terminal")
    endif()


    if(NOT BLACKMAGIC_DEVICE)
        add_custom_target(START_JLINK ALL
                COMMAND ${TERMINAL} "${DIR_OF_nRF5x_CMAKE}/runJLinkGDBServer-${NRF_TARGET}"
                COMMAND ${TERMINAL} "${DIR_OF_nRF5x_CMAKE}/runJLinkExe-${NRF_TARGET}"
                COMMAND sleep 2s
                COMMAND ${TERMINAL} "${DIR_OF_nRF5x_CMAKE}/runJLinkRTTClient"
                COMMENT "started JLink commands"
                )
    endif()

endmacro(nRF5x_setup)

# adds a target for comiling and flashing an executable
macro(nRF5x_addExecutable EXECUTABLE_NAME SOURCE_FILES)
    # executable
    add_executable(${EXECUTABLE_NAME} ${SDK_SOURCE_FILES} ${SOURCE_FILES})
    set_target_properties(${EXECUTABLE_NAME} PROPERTIES SUFFIX ".out")
    set_target_properties(${EXECUTABLE_NAME} PROPERTIES LINK_FLAGS "-Wl,-Map=${EXECUTABLE_NAME}.map")

    # additional POST BUILD setps to create the .bin and .hex files
    add_custom_command(TARGET ${EXECUTABLE_NAME}
            POST_BUILD
            COMMAND ${CMAKE_SIZE_UTIL} ${EXECUTABLE_NAME}.out
            COMMAND ${CMAKE_OBJCOPY} -O binary ${EXECUTABLE_NAME}.out "${EXECUTABLE_NAME}.bin"
            COMMAND ${CMAKE_OBJCOPY} -O ihex ${EXECUTABLE_NAME}.out "${EXECUTABLE_NAME}.hex"
            COMMENT "post build steps for ${EXECUTABLE_NAME}")

    if(BLACKMAGIC_DEVICE)
        add_custom_target("FLASH_${EXECUTABLE_NAME}" ALL
                DEPENDS ${EXECUTABLE_NAME}
                COMMAND ${CMAKE_GDB} -ex "set confirm off" -ex "target extended-remote ${BLACKMAGIC_DEVICE}" -ex "monitor swdp_scan" -ex "attach 1" -ex "load ${EXECUTABLE_NAME}.out" -ex "compare-sections" -ex "quit" ${EXECUTABLE_NAME}.out
                COMMENT "flashing ${EXECUTABLE_NAME}.hex"
                )
    else()
        # custom target for flashing the board
        add_custom_target("FLASH_${EXECUTABLE_NAME}" ALL
        DEPENDS ${EXECUTABLE_NAME}
        COMMAND ${NRFJPROG} --program ${EXECUTABLE_NAME}.hex -f ${NRF_TARGET} --sectorerase
        COMMAND sleep 0.5s
        COMMAND ${NRFJPROG} --reset -f ${NRF_TARGET}
        COMMENT "flashing ${EXECUTABLE_NAME}.hex"
        )
    endif()


endmacro()

# adds app-level scheduler library
macro(nRF5x_addAppScheduler)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/scheduler"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/scheduler/app_scheduler.c"
            )

endmacro(nRF5x_addAppScheduler)

macro(nRF5x_addSensorSim)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/sensorsim"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/sensorsim/sensorsim.c"
            )
endmacro(nRF5x_addSensorSim)

macro(nRF5x_addSPIS)
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_spis.c"
            "${NRF5_SDK_PATH}/integration/nrfx/legacy/nrf_drv_spis.c"
            )
endmacro(nRF5x_addSPIS)

macro(nRF5x_addSPI)
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_spim.c"
            "${NRF5_SDK_PATH}/integration/nrfx/legacy/nrf_drv_spi.c"
            )
endmacro(nRF5x_addSPI)

macro(nRF5x_Crypto)
    #file(GLOB tmp "${NRF5_SDK_PATH}/components/libraries/crypto/*.c")

    list(APPEND SDK_SOURCE_FILES
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_aead.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_aes.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_aes_shared.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_ecc.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_ecdh.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_ecdsa.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_eddsa.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_error.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_hash.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_hkdf.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_hmac.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_init.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_rng.c"
        "${NRF5_SDK_PATH}/components/libraries/crypto/nrf_crypto_shared.c"
        "${NRF5_SDK_PATH}/integration/nrfx/legacy/nrf_drv_rng.c"
        "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_rng.c"
        "${NRF5_SDK_PATH}/components/libraries/queue/nrf_queue.c"
    )
endmacro(nRF5x_Crypto)

macro(nRF5x_CryptoBackendOberon)
    #file(GLOB tmp "${NRF5_SDK_PATH}/components/libraries/crypto/*.c")

    list(APPEND SDK_SOURCE_FILES
    "${NRF5_SDK_PATH}/components/libraries/crypto/backend/oberon/oberon_backend_chacha_poly_aead.c"
    "${NRF5_SDK_PATH}/components/libraries/crypto/backend/oberon/oberon_backend_ecc.c"
    "${NRF5_SDK_PATH}/components/libraries/crypto/backend/oberon/oberon_backend_ecdh.c"
    "${NRF5_SDK_PATH}/components/libraries/crypto/backend/oberon/oberon_backend_ecdsa.c"
    "${NRF5_SDK_PATH}/components/libraries/crypto/backend/oberon/oberon_backend_eddsa.c"
    "${NRF5_SDK_PATH}/components/libraries/crypto/backend/oberon/oberon_backend_hash.c"
    "${NRF5_SDK_PATH}/components/libraries/crypto/backend/oberon/oberon_backend_hmac.c"
    "${NRF5_SDK_PATH}/components/libraries/crypto/backend/nrf_hw/nrf_hw_backend_init.c"
    "${NRF5_SDK_PATH}/components/libraries/crypto/backend/nrf_hw/nrf_hw_backend_rng.c"
    "${NRF5_SDK_PATH}/components/libraries/crypto/backend/nrf_hw/nrf_hw_backend_rng_mbedtls.c"
    "${NRF5_SDK_PATH}/external/mbedtls/library/aes.c"
    "${NRF5_SDK_PATH}/external/mbedtls/library/ctr_drbg.c"
  
  
    )
    if(NRF_TARGET MATCHES "nrf52")
    link_libraries(${NRF5_SDK_PATH}/external/nrf_oberon/lib/cortex-m4/hard-float/liboberon_3.0.1.a)
    endif()
    
endmacro(nRF5x_CryptoBackendOberon)


# adds app-level FIFO libraries
macro(nRF5x_addAppFIFO)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/fifo"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/fifo/app_fifo.c"
            )

endmacro(nRF5x_addAppFIFO)

# adds app-level Timer libraries
macro(nRF5x_addAppTimer)
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/timer/app_timer.c"
            )
endmacro(nRF5x_addAppTimer)

# adds app-level UART libraries
macro(nRF5x_addAppUART)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/uart"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/uart/app_uart_fifo.c"
            )

endmacro(nRF5x_addAppUART)

# adds app-level Button library
macro(nRF5x_addAppButton)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/button"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/button/app_button.c"
            )

endmacro(nRF5x_addAppButton)

# adds BSP (board support package) library
macro(nRF5x_addBSP WITH_BLE_BTN WITH_ANT_BTN WITH_NFC)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/bsp"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/bsp/bsp.c"
            )

    if (${WITH_BLE_BTN})
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/bsp/bsp_btn_ble.c"
                )
    endif ()

    if (${WITH_ANT_BTN})
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/bsp/bsp_btn_ant.c"
                )
    endif ()

    if (${WITH_NFC})
        list(APPEND SDK_SOURCE_FILES
                "${NRF5_SDK_PATH}/components/libraries/bsp/bsp_nfc.c"
                )
    endif ()

endmacro(nRF5x_addBSP)

# adds Bluetooth Low Energy GATT support library
macro(nRF5x_addBLEGATT)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/nrf_ble_gatt"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/nrf_ble_gatt/nrf_ble_gatt.c"
            )

endmacro(nRF5x_addBLEGATT)

# adds Bluetooth Low Energy advertising support library
macro(nRF5x_addBLEAdvertising)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/ble_advertising"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/ble_advertising/ble_advertising.c"
            )

endmacro(nRF5x_addBLEAdvertising)

# adds Bluetooth Low Energy advertising support library
macro(nRF5x_addBLEPeerManager)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/peer_manager"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/peer_manager/auth_status_tracker.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/gatt_cache_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/gatts_cache_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/id_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/nrf_ble_lesc.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_data_storage.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_database.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_id.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_manager.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/peer_manager_handler.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/pm_buffer.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/security_dispatcher.c"
            "${NRF5_SDK_PATH}/components/ble/peer_manager/security_manager.c"
    )

endmacro(nRF5x_addBLEPeerManager)

# adds app-level FDS (flash data storage) library
macro(nRF5x_addSAADC)
    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_saadc.c"
            "${NRF5_SDK_PATH}/modules/nrfx/drivers/src/nrfx_saadc.c"
    )

endmacro(nRF5x_addSAADC)

# adds app-level FDS (flash data storage) library
macro(nRF5x_addAppFDS)
    include_directories(
            "${NRF5_SDK_PATH}/components/libraries/fds"
            "${NRF5_SDK_PATH}/components/libraries/fstorage"
            "${NRF5_SDK_PATH}/components/libraries/experimental_section_vars"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/libraries/fds/fds.c"
            "${NRF5_SDK_PATH}/components/libraries/fstorage/nrf_fstorage.c"
            "${NRF5_SDK_PATH}/components/libraries/fstorage/nrf_fstorage_sd.c"
            "${NRF5_SDK_PATH}/components/libraries/fstorage/nrf_fstorage_nvmc.c"
    )

endmacro(nRF5x_addAppFDS)

# adds NFC library
# macro(nRF5x_addNFC)
#     # NFC includes
#     include_directories(
#             "${NRF5_SDK_PATH}/components/nfc/ndef/conn_hand_parser"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/conn_hand_parser/ac_rec_parser"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/conn_hand_parser/ble_oob_advdata_parser"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/conn_hand_parser/le_oob_rec_parser"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/ac_rec"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/ble_oob_advdata"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/ble_pair_lib"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/ble_pair_msg"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/common"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/ep_oob_rec"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/hs_rec"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/connection_handover/le_oob_rec"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/generic/message"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/generic/record"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/launchapp"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/parser/message"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/parser/record"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/text"
#             "${NRF5_SDK_PATH}/components/nfc/ndef/uri"
#             "${NRF5_SDK_PATH}/components/nfc/t2t_lib"
#             "${NRF5_SDK_PATH}/components/nfc/t2t_parser"
#             "${NRF5_SDK_PATH}/components/nfc/t4t_lib"
#             "${NRF5_SDK_PATH}/components/nfc/t4t_parser/apdu"
#             "${NRF5_SDK_PATH}/components/nfc/t4t_parser/cc_file"
#             "${NRF5_SDK_PATH}/components/nfc/t4t_parser/hl_detection_procedure"
#             "${NRF5_SDK_PATH}/components/nfc/t4t_parser/tlv"
#     )
# 
#     list(APPEND SDK_SOURCE_FILES
#             "${NRF5_SDK_PATH}/components/nfc"
#             )
# 
# endmacro(nRF5x_addNFC)

macro(nRF5x_addBLEService NAME)
    set(USE_SOFTDEVICE true)
    include_directories(
            "${NRF5_SDK_PATH}/components/ble/ble_services/${NAME}"
    )

    list(APPEND SDK_SOURCE_FILES
            "${NRF5_SDK_PATH}/components/ble/ble_services/${NAME}/${NAME}.c"
            )

endmacro(nRF5x_addBLEService)


if(USE_SOFTDEVICE)
    list(APPEND SDK_SOURCE_FILES
    "${NRF5_SDK_PATH}/components/softdevice/common/nrf_sdh_ble.c"
    "${NRF5_SDK_PATH}/components/ble/common/ble_advdata.c"
    "${NRF5_SDK_PATH}/components/ble/common/ble_conn_params.c"
    "${NRF5_SDK_PATH}/components/ble/common/ble_conn_state.c"
    "${NRF5_SDK_PATH}/components/ble/common/ble_srv_common.c"
    "${NRF5_SDK_PATH}/components/ble/ble_advertising/ble_advertising.c"
    "${NRF5_SDK_PATH}/components/ble/ble_link_ctx_manager/ble_link_ctx_manager.c"
    "${NRF5_SDK_PATH}/components/ble/ble_services/ble_nus/ble_nus.c"
    "${NRF5_SDK_PATH}/components/ble/nrf_ble_qwr/nrf_ble_qwr.c"
    )

endif()