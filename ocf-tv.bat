@echo off

SET keyname=id_rsa_tv
SET keypriv=%homedrive%%homepath%/.ssh/%keyname%
SET keyprivtype=%homedrive%%homepath%\.ssh\%keyname%
SET keypub=%homedrive%%homepath%/.ssh/%keyname%.pub
SET keypubtype=%homedrive%%homepath%\.ssh\%keyname%.pub
SET tvsink=alsa_output.pci-0000_00_03.0.hdmi-stereo
SET host=tv
::SET username=
SET samplerate=48000

SET usage1=usage: ocf-tv [-h]
SET usage2=              {connect,tunnel-audio,tunnel,t,audio,volume,vol,v,mute} ...

IF "%1"=="reset" GOTO reset
IF "%1"=="delete" GOTO delete
IF "%1"=="-h" GOTO help
IF "%1"=="--help" GOTO help
IF "%1"=="/?" GOTO help
IF "%1"=="help" GOTO help

IF NOT EXIST %keypub% (
echo Setting up SSH credentials...
IF EXIST %keypriv% (
echo y | ssh-keygen -b 4096 -t rsa -f %keypriv% -N "" -q >NUL
) ELSE (
ssh-keygen -b 4096 -t rsa -f %keypriv% -N "" -q >NUL
)
powershell -executionpolicy bypass -File FixUserFilePermissions.ps1 >NUL
type %keypubtype% | ssh -q -o StrictHostKeyChecking=no %username%@%host% "umask 077; test -d .ssh || mkdir .ssh ; cat >> .ssh/authorized_keys"
timeout /t 1 >NUL
)

IF "%1"=="" GOTO vnc
IF "%1"=="connect" GOTO vnc
IF "%1"=="tunnel" GOTO tunnel
IF "%1"=="tunnel-audio" GOTO tunnel
IF "%1"=="t" GOTO tunnel
IF "%1"=="audio" GOTO tunnel
IF "%1"=="audio" GOTO tunnel
IF "%1"=="volume" GOTO vol
IF "%1"=="vol" GOTO vol
IF "%1"=="v" GOTO vol
IF "%1"=="mute" GOTO mute
SET msg=ocf-tv: error: argument command: invalid choice: '%1' (choose from 'connect', 'tunnel-audio', 'tunnel', 't', 'audio', 'volume', 'vol', 'v', 'mute')
GOTO motd

:vnc
start /b ssh -i %keypriv% -t -k -N -o ExitOnForwardFailure=yes -o BatchMode=yes -o StrictHostKeyChecking=no -L 20000:localhost:5900 %username%@%host% & start tvnviewer localhost::20000
<NUL SET /p "=Press enter to close VNC viewer..."
pause >NUL
tasklist | find /i "tvnviewer.exe" >NUL && taskkill /im tvnviewer.exe /F >NUL
tasklist | find /i "ssh.exe" >NUL && taskkill /im ssh.exe /F >NUL
GOTO End1

:tunnel
WLStream | ssh -i %keypriv% -o StrictHostKeyChecking=no %username%@%host% "echo 'Press enter to close the tunnel...' && cat - | pacat -v --playback --format float32le --rate %samplerate% --latency-msec=50 --process-time-msec=50"
GOTO End1

:vol
IF "%2"=="" (
ssh -i %keypriv% -o StrictHostKeyChecking=no %username%@%host% "PULSE_SERVER=127.0.0.1 pactl list sinks | awk '/Name: %tvsink%$/ {{ target = NR + 7 }}; NR == target {{ print $5 }}'"
GOTO End1
) ELSE (
IF %2 leq 150 (
IF %2 geq 0 (
ssh -i %keypriv% -o StrictHostKeyChecking=no %username%@%host% "PULSE_SERVER=127.0.0.1 pactl set-sink-volume %tvsink% %2%% && echo %2%%" 
GOTO End1
)
GOTO voler
) ELSE (
:voler
SET msg=ocf-tv volume: error: argument amount: Volume out of bounds: %2 not in [0, 150]
GOTO motd
)
)
GOTO End1

:mute
ssh -i %keypriv% -o StrictHostKeyChecking=no %username%@%host% "PULSE_SERVER=127.0.0.1 pactl set-sink-mute 0 toggle"
GOTO End1

:help
echo %usage1%
echo %usage2%
echo(
echo Control the OCF television.
echo(
echo positional arguments:
echo   {connect,tunnel-audio,tunnel,t,audio,volume,vol,v,mute}
echo     connect             Open a VNC instance to view the TV screen
echo     tunnel-audio (tunnel, t, audio)
echo                         Create a PulseAudio tunnel to the TV and transfer all
echo                         local sink inputs to that tunnel
echo     volume (vol, v)     Set the volume on the TV's primary PulseAudio sink
echo     mute                Toggle mute on the TV
echo     reset               Resets your SSH credentials/keys
echo     delete              Deletes your SSH credentials/keys
echo(
echo optional arguments:
echo   -h, --help            Show this help message and exit
GOTO End1

:motd
echo %usage1%
echo %usage2%
echo %msg%
GOTO End1

:reset
echo Resetting SSH credentials...
del /Q %keyprivtype% 2>NUL
del /Q %keypubtype% 2>NUL
ssh-keygen -b 4096 -t rsa -f %keypriv% -N "" -q >NUL
powershell -executionpolicy bypass -File FixUserFilePermissions.ps1 >NUL
type %keypubtype% | ssh -q -o StrictHostKeyChecking=no %username%@%host% "sed -i '/%COMPUTERNAME%/Id' .ssh/authorized_keys; umask 077; test -d .ssh || mkdir .ssh ; cat >> .ssh/authorized_keys"
GOTO End1

:delete
echo Deleting SSH credentials...
ssh -i %keypriv% -q -o StrictHostKeyChecking=no %username%@%host% "sed -i '/%COMPUTERNAME%/Id' .ssh/authorized_keys"
del /Q %keyprivtype% 2>NUL
del /Q %keypubtype% 2>NUL
GOTO End1

:End1