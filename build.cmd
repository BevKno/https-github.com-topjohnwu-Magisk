@ECHO OFF
SETLOCAL ENABLEEXTENSIONS
SET me=%~nx0
SET parent=%~dp0
SET tab=	
SET OK=
SET DEBUG=

CD %parent%

call :%~1 "%~2" "%~3"
IF NOT DEFINED OK CALL :usage

EXIT /B %ERRORLEVEL%
:usage
  ECHO %me% all ^<version name^> ^<version code^>
  ECHO %tab%Build binaries, zip, and sign Magisk
  ECHO %tab%This is equlivant to first ^<build^>, then ^<zip^>
  ECHO %me% clean
  ECHO %tab%Cleanup compiled / generated files
  ECHO %me% build ^<version name^> ^<version code^>
  ECHO %tab%Build the binaries with ndk
  ECHO %me% debug
  ECHO %tab%Build the binaries with the debug flag on
  ECHO %tab%Call ^<zip^> afterwards if you want to flash on device
  ECHO %me% zip ^<version name^>
  ECHO %tab%Zip and sign Magisk
  ECHO %me% uninstaller
  ECHO %tab%Zip and sign the uninstaller
  EXIT /B 1

:all
  SET OK=y
  CALL :build "%~1" "%~2"
  CALL :zip "%~1"
  EXIT /B %ERRORLEVEL%

:debug
  SET OK=y
  SET DEBUG=-DDEBUG
  CALL :build "%~1" "%~2"
  EXIT /B %ERRORLEVEL%

:build
  SET OK=y
  IF [%~1] == [] (
    CALL :error "Missing version info"
    CALL :usage
    EXIT /B %ERRORLEVEL%
  )
  IF [%~2] == [] (
    CALL :error "Missing version info"
    CALL :usage
    EXIT /B %ERRORLEVEL%
  )
  SET BUILD=Build
  IF NOT [%DEBUG%] == [] (
    SET BUILD=Debug
  )
  ECHO ************************
  ECHO * %BUILD%: VERSION=%~1 CODE=%~2
  ECHO ************************
  FOR /F "tokens=* USEBACKQ" %%F IN (`where ndk-build`) DO (
    IF [%%F] == [] (
      CALL :error "Please add ndk-build to PATH!"
      EXIT /B 1
    )
  )
  CALL ndk-build APP_CFLAGS="-DMAGISK_VERSION=%~1 -DMAGISK_VER_CODE=%~2 %DEBUG%" -j%NUMBER_OF_PROCESSORS% || CALL :error "Magisk binary tools build failed...."
  IF %ERRORLEVEL% NEQ 0 EXIT /B %ERRORLEVEL%
  ECHO ************************
  ECHO * Copying binaries
  ECHO ************************
  CALL :mkcp libs\armeabi-v7a\magisk zip_static\arm
  CALL :mkcp libs\armeabi-v7a\magiskboot zip_static\arm
  CALL :mkcp libs\arm64-v8a\magisk zip_static\arm64
  CALL :mkcp libs\arm64-v8a\magiskboot zip_static\arm64
  CALL :mkcp libs\x86\magisk zip_static\x86
  CALL :mkcp libs\x86\magiskboot zip_static\x86
  CALL :mkcp libs\x86_64\magisk zip_static\x64
  CALL :mkcp libs\x86_64\magiskboot zip_static\x64
  CALL :mkcp libs\armeabi-v7a\magiskboot uninstaller\arm
  CALL :mkcp libs\arm64-v8a\magiskboot uninstaller\arm64
  CALL :mkcp libs\x86\magiskboot uninstaller\x86
  CALL :mkcp libs\x86_64\magiskboot uninstaller\x64
  EXIT /B %ERRORLEVEL%

:clean
  SET OK=y
  ECHO ************************
  ECHO * Cleaning up
  ECHO ************************
  CALL ndk-build clean
  2>NUL RMDIR /S /Q zip_static\arm
  2>NUL RMDIR /S /Q zip_static\arm64
  2>NUL RMDIR /S /Q zip_static\x86
  2>NUL RMDIR /S /Q zip_static\x64
  2>NUL DEL zip_static\META-INF\com\google\android\update-binary
  2>NUL DEL zip_static\common\*.sh
  2>NUL DEL zip_static\common\*.rc
  2>NUL RMDIR /S /Q uninstaller\common
  2>NUL RMDIR /S /Q uninstaller\arm
  2>NUL RMDIR /S /Q uninstaller\arm64
  2>NUL RMDIR /S /Q uninstaller\x86
  2>NUL RMDIR /S /Q uninstaller\x64
  EXIT /B 0

:zip
  SET OK=y
  IF [%~1] == [] (
    CALL :error "Missing version info"
    CALL :usage
    EXIT /B %ERRORLEVEL%
  )
  IF NOT EXIST "zip_static\arm\magiskboot" CALL :error "Missing binaries! Please run '%me% build' before zipping!"
  IF %ERRORLEVEL% NEQ 0 EXIT /B %ERRORLEVEL%
  ECHO ************************
  ECHO * Adding version info
  ECHO ************************
  powershell.exe -nologo -noprofile -command "(gc -Raw scripts\flash_script.sh) -replace 'MAGISK_VERSION_STUB', 'Magisk v%~1 Installer' | sc zip_static\META-INF\com\google\android\update-binary"
  rem powershell.exe -nologo -noprofile -command "(gc -Raw scripts\magic_mask.sh) -replace 'MAGISK_VERSION_STUB', 'setprop magisk.version \"%~1\"' | sc zip_static\common\magic_mask.sh"
  ECHO ************************
  ECHO * Copying Files
  ECHO ************************
  COPY /Y scripts\custom_ramdisk_patch.sh zip_static\common\custom_ramdisk_patch.sh
  COPY /Y scripts\init.magisk.rc zip_static\common\init.magisk.rc
  ECHO ************************
  ECHO * Zipping Magisk v%~1
  ECHO ************************
  CD zip_static
  2>NUL DEL "..\Magisk-v%~1.zip"
  ..\ziptools\win_bin\zip "..\Magisk-v%~1.zip" -r .
  CD ..\
  CALL :sign_zip "Magisk-v%~1.zip"
  EXIT /B %ERRORLEVEL%

:uninstaller
  SET OK=y
  IF NOT EXIST "uninstaller\arm\magiskboot" CALL :error "Missing binaries! Please run '%me% build' before zipping!"
  IF %ERRORLEVEL% NEQ 0 EXIT /B %ERRORLEVEL%
  ECHO ************************
  ECHO * Copying Files
  ECHO ************************
  CALL :mkcp scripts\magisk_uninstaller.sh uninstaller\common
  ECHO ************************
  ECHO * Zipping uninstaller
  ECHO ************************
  FOR /F "tokens=* USEBACKQ" %%F IN (`ziptools\win_bin\date "+%%Y%%m%%d"`) DO (set timestamp=%%F)
  CD uninstaller
  2>NUL DEL "../Magisk-uninstaller-%timestamp%.zip"
  ..\ziptools\win_bin\zip "../Magisk-uninstaller-%timestamp%.zip" -r .
  CD ..\
  CALL :sign_zip "Magisk-uninstaller-%timestamp%.zip"
  EXIT /B %ERRORLEVEL%

:sign_zip
  IF NOT EXIST "ziptools\win_bin\zipadjust.exe" (
    ECHO ************************
    ECHO * Compiling ZipAdjust
    ECHO ************************
    gcc -o ziptools\win_bin\zipadjust ziptools\src\*.c -lz || CALL :error "ZipAdjust Build failed...."
    IF %ERRORLEVEL% NEQ 0 EXIT /B %ERRORLEVEL%
  )
  SET basename="%~1"
  SET basename="%basename:.zip=%"
  ECHO ************************
  ECHO * First sign %~1
  ECHO ************************
  java -jar "ziptools\signapk.jar" "ziptools\test.certificate.x509.pem" "ziptools\test.key.pk8" "%~1" "%basename:"=%-firstsign.zip"
  ECHO ************************
  ECHO * Adjusting %~1
  ECHO ************************
  ziptools\win_bin\zipadjust "%basename:"=%-firstsign.zip" "%basename:"=%-adjusted.zip"
  ECHO ************************
  ECHO * Final sign %~1
  ECHO ************************
  java -jar "ziptools\minsignapk.jar" "ziptools\test.certificate.x509.pem" "ziptools\test.key.pk8" "%basename:"=%-adjusted.zip" "%basename:"=%-signed.zip"

  MOVE /Y "%basename:"=%-signed.zip" "%~1"
  DEL "%basename:"=%-adjusted.zip" "%basename:"=%-firstsign.zip"
  EXIT /B %ERRORLEVEL%

:mkcp
  2>NUL MKDIR "%~2"
  2>NUL COPY /Y "%~1" "%~2"
  EXIT /B 0

:error
  ECHO.
  ECHO ! %~1
  ECHO.
  EXIT /B 1
