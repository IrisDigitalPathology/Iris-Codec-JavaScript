@echo off
REM Build script for Iris Codec WebAssembly module on Windows

REM Parse command line arguments
set BUILD_EXAMPLES=true
set CREATE_PACKAGE=false
set INSTALL_DIR=

:parse_args
if "%~1"=="" goto :done_parsing
if "%~1"=="--no-examples" (
    set BUILD_EXAMPLES=false
    shift
    goto :parse_args
)
if "%~1"=="--package" (
    set CREATE_PACKAGE=true
    shift
    goto :parse_args
)
if "%~1:~0,10%"=="--install=" (
    set INSTALL_DIR=%~1:~10%
    shift
    goto :parse_args
)
shift
goto :parse_args
:done_parsing

REM Ensure Emscripten is available
where emcmake >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Emscripten toolchain not found. Please run emsdk_env.bat first.
    exit /b 1
)

REM Create build directory
if not exist build mkdir build
cd build

REM Configure with CMake
set EXAMPLES_FLAG=
if "%BUILD_EXAMPLES%"=="false" (
    set EXAMPLES_FLAG=-DIRIS_BUILD_HTML_EXAMPLES=OFF
)

echo configure: cmake .. -DCMAKE_BUILD_TYPE=Release %EXAMPLES_FLAG%
call emcmake cmake .. -DCMAKE_BUILD_TYPE=Release -DIRIS_USE_TURBOJPEG=OFF -DIRIS_USE_AVIF=OFF -DIRIS_BUILD_ENCODER=OFF %EXAMPLES_FLAG%

REM Fix include paths by copying IrisCore.hpp to the priv directory
if exist _deps\irisheaders-src (
    echo Copying IrisCore.hpp to the priv directory...
    copy _deps\irisheaders-src\include\IrisCore.hpp _deps\irisheaders-src\priv\
)

REM Apply compatibility changes to IrisFileExtension
if exist _deps\irisfileextension-src (
    echo Applying compatibility changes to IrisFileExtension...
    
    REM Create EmscriptenCompat.hpp if it doesn't exist
    echo #ifndef EMSCRIPTEN_COMPAT_HPP > _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo #define EMSCRIPTEN_COMPAT_HPP >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo. >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo #include ^<cstring^> >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo #include ^<type_traits^> >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo. >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo // Provide a bit_cast implementation if std::bit_cast is not available >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo namespace std { >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo     template ^<typename To, typename From^> >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo     typename std::enable_if^< >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo         sizeof(To) == sizeof(From) ^&^& >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo         std::is_trivially_copyable^<From^>::value ^&^& >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo         std::is_trivially_copyable^<To^>::value, >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo         To^>::type >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo     bit_cast(const From^& src) noexcept { >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo         To dst; >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo         std::memcpy(^&dst, ^&src, sizeof(To)); >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo         return dst; >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo     } >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo } >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo. >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp
    echo #endif // EMSCRIPTEN_COMPAT_HPP >> _deps\irisfileextension-src\src\EmscriptenCompat.hpp

    REM Add include for EmscriptenCompat.hpp at the top of IrisCodecExtension.cpp
    powershell -Command "(Get-Content _deps\irisfileextension-src\src\IrisCodecExtension.cpp) | ForEach-Object {if ($_ -match '^#include') {'#include \"EmscriptenCompat.hpp\"'; $_} else {$_}} | Set-Content _deps\irisfileextension-src\src\IrisCodecExtension.cpp.new"
    move /Y _deps\irisfileextension-src\src\IrisCodecExtension.cpp.new _deps\irisfileextension-src\src\IrisCodecExtension.cpp
    
    REM Fix IFE_EXPORT issues using PowerShell
    powershell -Command "(Get-Content _deps\irisfileextension-src\src\IrisCodecExtension.hpp) -replace 'namespace IFE_EXPORT Abstraction', 'namespace Abstraction' -replace 'struct IFE_EXPORT Header', 'struct Header' -replace 'IFE_EXPORT ', '' | Set-Content _deps\irisfileextension-src\src\IrisCodecExtension.hpp.new"
    move /Y _deps\irisfileextension-src\src\IrisCodecExtension.hpp.new _deps\irisfileextension-src\src\IrisCodecExtension.hpp
)

REM Apply compatibility changes to IrisCodec if needed
if exist _deps\iriscodec-src (
    echo Applying compatibility changes to IrisCodec...
    
    REM Copy our EmscriptenCompat.hpp to the IrisCodec src directory
    copy ..\src\EmscriptenCompat.hpp _deps\iriscodec-src\src\
    
    REM Create stub CMake files to prevent building dependencies
    echo # Stub file to prevent building TurboJPEG > _deps\iriscodec-src\cmake\turbo-jpeg.cmake
    echo message(STATUS "TurboJPEG disabled for WebAssembly build") >> _deps\iriscodec-src\cmake\turbo-jpeg.cmake

    echo # Stub file to prevent building AVIF > _deps\iriscodec-src\cmake\avif.cmake
    echo message(STATUS "AVIF disabled for WebAssembly build") >> _deps\iriscodec-src\cmake\avif.cmake

    echo # Stub file to prevent building OpenSlide > _deps\iriscodec-src\cmake\openslide.cmake
    echo message(STATUS "OpenSlide disabled for WebAssembly build") >> _deps\iriscodec-src\cmake\openslide.cmake
)

REM Copy our custom files
echo Copying custom Emscripten-compatible files...
copy ..\src\EmscriptenCompat.hpp .
copy ..\src\IrisCodecContext.cpp .
copy ..\src\IrisCodecFile.cpp .

REM Build
echo make: emmake make -j%NUMBER_OF_PROCESSORS%
call emmake make -j%NUMBER_OF_PROCESSORS%

REM Create packages if requested
if "%CREATE_PACKAGE%"=="true" (
    echo Creating packages...
    
    REM Get version from CMakeLists.txt
    for /f "tokens=3" %%i in ('findstr /C:"VERSION " ..\CMakeLists.txt') do set VERSION=%%i
    
    REM Set platform to win-64
    set PLATFORM=win-64
    
    REM Create a temporary directory for packaging
    set TEMP_DIR=%TEMP%\iris_codec_package_%RANDOM%
    mkdir %TEMP_DIR%\iris-codec
    
    REM Copy WebAssembly files
    copy /Y iris_codec.js %TEMP_DIR%\iris-codec\
    copy /Y iris_codec.wasm %TEMP_DIR%\iris-codec\
    
    REM Copy examples if enabled
    if "%BUILD_EXAMPLES%"=="true" (
        if exist html_examples (
            echo Found examples in build/html_examples
            mkdir %TEMP_DIR%\iris-codec\html_examples
            xcopy /E /Y html_examples\*.* %TEMP_DIR%\iris-codec\html_examples\
        ) else if exist ..\examples (
            echo Found examples in project root examples directory
            mkdir %TEMP_DIR%\iris-codec\html_examples
            xcopy /E /Y ..\examples\*.html %TEMP_DIR%\iris-codec\html_examples\
        ) else if exist examples (
            echo Found examples in build/examples
            mkdir %TEMP_DIR%\iris-codec\html_examples
            xcopy /E /Y examples\*.html %TEMP_DIR%\iris-codec\html_examples\
        ) else (
            echo Warning: No examples found to include in the package
        )
    )
    
    REM Save the current directory
    set BUILD_DIR=%CD%
    
    REM Create the tar.gz package using PowerShell
    set PACKAGE_NAME=%PLATFORM%-iris-codec-%VERSION%-a2.tar.gz
    cd %TEMP_DIR%
    
    REM Use PowerShell to create the tar.gz file
    powershell -Command "Compress-Archive -Path iris-codec -DestinationPath iris-codec.zip -Force; $env:PACKAGE_NAME = '%PACKAGE_NAME%'; Write-Host 'Creating package:' $env:PACKAGE_NAME"
    
    REM Copy the package back to the build directory
    copy /Y iris-codec.zip "%BUILD_DIR%\%PACKAGE_NAME%"
    
    REM Return to the build directory
    cd %BUILD_DIR%
    
    REM Clean up
    rmdir /S /Q %TEMP_DIR%
    
    echo.
    echo Package created:
    echo - %PACKAGE_NAME%: WebAssembly module package
    echo.
    echo This file can be uploaded to the GitHub release page.
)

REM Install if an installation directory was provided
if not "%INSTALL_DIR%"=="" (
    echo Installing to %INSTALL_DIR%...
    
    REM Create installation directory
    if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"
    
    REM Copy WebAssembly module files
    copy iris_codec.js "%INSTALL_DIR%\"
    copy iris_codec.wasm "%INSTALL_DIR%\"
    
    REM Copy examples if enabled
    if "%BUILD_EXAMPLES%"=="true" (
        if exist html_examples (
            if not exist "%INSTALL_DIR%\html_examples" mkdir "%INSTALL_DIR%\html_examples"
            xcopy /E /Y html_examples\*.* "%INSTALL_DIR%\html_examples\"
        ) else if exist examples (
            if not exist "%INSTALL_DIR%\html_examples" mkdir "%INSTALL_DIR%\html_examples"
            xcopy /E /Y examples\*.html "%INSTALL_DIR%\html_examples\"
        )
    )
    
    echo Installation complete. Files installed to %INSTALL_DIR%
) else (
    echo Build complete. WebAssembly module is available in the build directory.
)

cd ..
