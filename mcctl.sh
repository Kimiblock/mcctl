#!/bin/bash

log='~/mcctl.log'
log_error='~/mcctl_debug.log'

######Function Start######
#Merge BuildTools log to script log
function mergeBuildToolsLog(){
    echo '[Info] printing BuildTools log'
    cat BuildTools.log.txt
}

#Print copyright
function printCopyright(){
    echo '[Info] This script is written by Kimiblock.'
}

#removeScript
function uninstallService(){
    checkServiceFileInstalled
    if [ ${service} = enabled ]; then
        sudo systemctl disable --now mcctl.service
        sudo rm -rf /etc/systemd/system/mcctl.service
    elif [ ${service} = disabled ]; then
        sudo rm -rf /etc/systemd/system/mcctl.service
    else
        echo '[Warn] mcctl.service doesnt exist'
    fi
}

#Check installed
function checkScriptInstalled(){
    echo '[Info] Checking if you have mcctl installed'
    if [ -f /usr/bin/mcctl ]; then
        echo '[Info] mcctl detected and installed'
    else
        echo '[Info] mcctl missing, press Enter to install or any other key to abort'
        unset confirm
        read confirm
        if [ ! ${confirm} ]; then
            installScript
        else
            exitScript 13
        fi
    fi
}

#Check service file installed
function checkServiceFileInstalled(){
    echo '[Info] Checking if you have mcctl service installed'
    if [ -f /etc/systemd/system/mcctl.service ]; then
        echo '[Info] mcctl service detected and start at boot disabled'
        service=disabled
    elif [ -f /etc/systemd/system/multi-user.target.wants/mcctl.service ]; then
        echo '[Info] mcctl service detected and start at boot enabled'
        service=enabled
    else
        echo '[Info] mcctl service missing'
        service=no
    fi
}


#Install script
function installScript(){
    echo '[Info] Downloading script'
    rm -rf mcctl 2>/dev/null
    git clone https://github.com/Kimiblock/mcctl.git 2>/dev/null 1>/dev/null
    if [ ! $? = 0 ]; then
        exitScript 11
    fi
    echo '[Info] Installing script, asking root permission'
    pathPrevious=`pwd`
    cd mcctl
    mv mcctl.sh mcctl
    sudo mv mcctl /usr/bin
    if [ ! $? = 0 ]; then
        exitScript 12
    fi
    sudo chmod +x /usr/bin/mcctl
    if [ ! $? = 0 ]; then
        exitScript 12
    fi
    cd ${pathPrevious}
    rm -rf mcctl
    echo '[Info] Script installed'
}

#Uninstall script
function uninstallScript(){
    echo '[Info] Uninstalling mcctl from your system'
    sudo rm -rf /usr/bin/mcctl
    echo '[Info] Uninstalled mcctl from your system'

}

#Create service file
function createStartupService(){
    checkSystemd
    flags=`echo $@ | cut -c 10-`
    echo '[Info] Creating service file'
    echo """
[Unit]
Description=minecraft-server-control's start module
[Service]
ExecStart=env version=${version} serverPath=${serverPath} mcctl ${flags}
[Install]
WantedBy=multi-user.target
    """ >mcctl.service
    sleep 3s
    if [ ! ${EDITOR} ]; then
        nano mcctl.service
    else
        ${EDITOR} mcctl.service
    fi
    echo "[Info] Type 'Confirm' to confirm or any other key to cancel"
    read checkConfirm
    if [ ${checkConfirm} = 'Confirm' ]; then
        sudo mv mcctl.service /etc/systemd/system/
        sudo systemctl enable mcctl.service
    else
        echo '[Info] Cancelled'
    fi
}

#Check systemd function
function checkSystemd(){
    echo '[Info] Checking if you have systemd installed'
    systemctl --version 1>/dev/null 2>/dev/null
    if [ $? = 127 ]; then
        exitScript 10
    elif [ $? = 0 ]; then
        echo '[Info] Systemd installed and functioned correctly'
    else
        echo "[Warn] Systemd installed but returned an error code $?"
    fi
}

#Install prerequests
function installRequirements(){
    echo '[Info] Installing requirements'
    detectPackageManager
    if [ ${packageManager}= 'pacman' ]; then
        sudo pacman -S jre-openjdk-headless screen wget --noconfirm --needed
    elif [ ${packageManager} = 'apt' ]; then
        sudo apt install -y default-jdk screen wget
    elif [ ${packageManager} = 'dnf' ]; then
        echo "[Critical] dnf not supported"
        exitScript 9
    fi
    echo '[Info] Finished installing requirements'
}

#Check Screen
function checkScreen(){
    echo '[Info]Checking if you have already installed screen'
    screen --version 2>/dev/null
    if [[ $? =~ 127 ]]; then
        exitScript 8
    fi
}

#Create Screen
function createScreen(){
    echo "[Info] Creating new screen ${screenName}.${screenId}"
    screen -dmS ${screenName}
    screenId=`screen -ls | grep .${screenName} | awk '{print $1}' | cut -d "." -f 1`
    screen -x ${screenId} -p 0 -X stuff "${screenCommand}"
    screen -x ${screenId} -p 0 -X stuff '\r'
    echo '[Info] Screen created'
}



#Clean leftovers
function cleanFile(){
    if [[ $@ =~ 'buildTools' ]]; then
        echo '[Info] Cleaning Spigot leftovers'
        for trash in 'apache-maven-3.6.0' 'BuildData' 'Bukkit' 'CraftBukkit' 'Spigot' 'work'; do
            rm -fr ${trash} 1>/dev/null 2>/dev/null
        done
    unset trash
    fi
    if [[ $@ =~ 'log' ]]; then
        echo '[Info] Cleaning logs'
        for logFiles in 'mcctl.log' 'BuildTools.log.txt' 'wget-log' 'mcctl_debug.log'; do
            rm -f ${logFiles}
        done
        unset logFiles
    fi
}

#Exit script
function exitScript(){
    if [ $@ = 0 ]; then
    exit $@
    else
        echo '[Critical] Exit code detected!'
        echo "Exit code: $@ "
        echo '[Critical] You may follow the instructions to debug'
        if [[ $@ = 1 ]]; then
            sign='Unknown error'
        elif [[ $@ = 2 ]]; then
            sign='Can not create directory'
        elif [[ $@ = 3 ]]; then
            sign='Non-64-bit system detected, use unsafe to override'
        elif [[ $@ = 4 ]];then
            sign='Environment variables not set'
        elif [[ $@ = 5 ]]; then
            sign='System update failed'
        elif [[ $@ = 6 ]]; then
            sign='BuildTools failed to start, use clean to fix it'
        elif [[ $@ = 7 ]]; then
            sign='No jar file detected'
        elif [[ $@ = 8 ]]; then
            sign='Screen not installed'
        elif [[ $@ = 9 ]]; then
            sign='Package manager not supported'
        elif [[ $@ = '10' ]]; then
            sign='Systemd missing'
        elif [[ $@ = '11' ]]; then
            sign='Network unrechable'
        elif [[ $@ = 12 ]]; then
            sign='Permission denied'
        elif [[ $@ = 13 ]]; then
            sign='User cancelled'
        elif [[ ! $@ ]]; then
            sign='Internal error'
        else
            sign="Undefined error code"
        fi
        echo "[Critical] ${sign}"
        echo '[Critical] Exitting...'
        unset ${sign}
        exit $@
    fi
}

#Create folders for the first time
function createFolder(){
    if [ ! -d ${serverPath} ]; then
        echo '[Info] Path to server is empty, creating new directory'
        mkdir ${serverPath}
        mkdir ${serverPath}/plugins
        if [ $? = 1 ]; then
        echo '[Info] mkdir returned error code 1, retrying with sudo'
            if [ $@ =~ 'unattended' ]; then
                echo '[Warn] unattended flag detected.'
                exitScript 2
            else
                if [ `whoami` = root ]; then
                    exitScript 2
                else
                    sudo mkdir ${serverPath}
                    sudo mkdir ${serverPath}/plugins
                fi
            fi
        fi
        echo '[Info] Directory created.'
    else
        echo '[Info] Directory already exists'
    fi
    if [ ! -d ${serverPath}/plugins ]; then
        echo '[Info] Plugins folder not found, trying to create'
        mkdir ${serverPath}/plugins
        if [ $? = 1 ]; then
            echo '[Info] mkdir failed, trying with root'
            if [[ $@ =~ 'unattended' ]]; then
                sudo mkdir ${serverPath}/plugins
            else
                echo '[Warn] unattended flag detected'
                exitScript 2
            fi
            if [ $? = 1 ]; then
                echo '[Warn] Plugins folder cannot be created'
                exitScript 2
            fi
        fi
    else
        echo '[Info] Directory already exists'
    fi
}

#Build origin server
function buildMojang(){
    if [ ${version} = 1.19 ]; then
        url=https://launcher.mojang.com/v1/objects/e00c4052dac1d59a1188b2aa9d5a87113aaf1122/server.jar
    fi
    wget ${url} >/dev/null 2>/dev/null
    mv server.jar Minecraft-latest.jar
    update Minecraft-latest.jar
}

#Build Spigot
function buildSpigot(){
    url="https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar"
    checkFile='BuildTools.jar'
    echo "[Info] Downloading BuildTools for Spigot..."
    wget ${url} >/dev/null 2>/dev/null
    java -jar $checkFile nogui --rev ${version} >/dev/null 2>/dev/null
    if [ ! $? = 0 ]; then
        exitScript 6
    fi
    rm -rf ${checkConfig}
    mv spigot-*.jar Spigot-latest.jar
    update Spigot-latest.jar
}

#testPackageManager
function detectPackageManager(){
    echo "[Info] Detecting package manager..."
    if [[ $@ =~ 'nosudo' ]]; then
        if [[ $(apt install ) ]]; then
            echo '[Info] Detected apt'
            packageManager='apt'
        elif [[ $(pacman -h ) ]]; then
            echo '[Info] Detected pacman'
            packageManager='pacman'
        elif [[ $(dnf install ) ]]; then
            echo '[Info] Detected dnf'
            packageManager='dnf'
        else
            packageManager='unknown'
        fi
    else
        if [[ $(sudo apt install ) ]]; then
            echo '[Info] Detected apt'
            packageManager='apt'
        elif [[ $(sudo pacman -h ) ]]; then
            echo '[Info] Detected pacman'
            packageManager='pacman'
        elif [[ $(sudo dnf install ) ]]; then
            echo '[Info] Detected dnf'
            packageManager='dnf'
        else
            packageManager='unknown'
        fi
    fi
}
#checkConfig
checkConfig(){
    if [ ! ${version} ]; then
        exitScript 4
    fi
    if [ ! ${serverPath} ]; then
        exitScript 4
    fi
    if [ ! $build ]; then
        export build=500
    fi
}
#removeJarFile
function clean(){
    echo "[Info] Cleaning"
    rm -rf *.jar 1>/dev/null 2>/dev/null
    rm -rf *.check 1>/dev/null 2>/dev/null
    rm -rf *.1 1>/dev/null 2>/dev/null
    rm -rf *.2 1>/dev/null 2>/dev/null
}
#moveFile
function update(){
    echo "[Info] Updating jar file..."
    if [[ $@ = "Paper-latest.jar" ]]; then
        mv $@ ${serverPath}
    elif [[ $@ = "Spigot-latest.jar" ]]; then
        mv $@ ${serverPath}
    elif [[ $@ = "Minecraft-latest.jar" ]]; then
        mv $@ ${serverPath}
    else
        mv $@ ${serverPath}/plugins
    fi
}
#versionCompare
function versionCompare(){
    echo "[Info] Making sure you're up to date."
    if [ $isPlugin = true ]; then
        checkPath="${serverPath}/plugins"
    else
        checkPath="${serverPath}"
    fi
    diff -q "${checkPath}/${checkFile}" "${checkFile}" >/dev/null 2>/dev/null
    return $?
}
#integrityProtect
function integrityProtect(){
    echo "[Info] Checking file integrity."
    if [[ $@ =~ "unsafe" ]]; then
        echo "[Warn] Default protection disabled. USE AT YOUR OWN RISK!"
        return 0
    else
        echo "[Info] Verifing ${checkFile}"
        if [ ${isPlugin} = false ]; then
            checkFile=Paper-latest.jar
            wget $url >/dev/null 2>/dev/null
            mv paper-*.jar Paper-latest.jar.check
            diff -q Paper-latest.jar.check Paper-latest.jar >/dev/null 2>/dev/null
            return $?
        else
            mv $checkFile "${checkFile}.check"
            wget $url >/dev/null 2>/dev/null
            diff -q $checkFile "${checkFile}.check" >/dev/null 2>/dev/null
            return $?
        fi
    fi
    if [ $? = 1 ]; then
        echo "[Warn] Checking job done, repairing ${checkFile}."
        redownload
    else
        echo "[Info] Ckecking job done, ${ckeckFile} verified."
        clean
    fi
}
function redownload(){
    clean
    if [ ${isPlugin} = false ]; then
        checkFile=Paper-latest.jar
        wget $url >/dev/null 2>/dev/null
        mv paper-*.jar Paper-latest.jar
        integrityProtect
    else
        wget $url >/dev/null 2>/dev/null
        integrityProtect
    fi
}
#pluginUpdate
function pluginUpdate(){
    echo "[Info] Updating ${checkFile}"
    if [ $@ = Floodgate ]; then
        pluginName="$@"
        url="https://ci.opencollab.dev/job/GeyserMC/job/Floodgate/job/master/lastSuccessfulBuild/artifact/spigot/target/floodgate-spigot.jar"
    elif [ $@ = Geyser ]; then
        pluginName="$@"
        url="https://ci.opencollab.dev/job/GeyserMC/job/Geyser/job/master/lastSuccessfulBuild/artifact/bootstrap/spigot/target/Geyser-Spigot.jar"
    elif [ $@ = SAC ]; then
        pluginName="$@"
        url="https://www.spigotmc.org/resources/soaromasac-lightweight-cheat-detection-system.87702/download?version=455200"
    elif [ $@ = MTVehicles ]; then
        pluginName="$@"
        url="https://www.spigotmc.org/resources/mtvehicles-vehicle-plugin-free-downloadable.80910/download?version=452759"
    else
        echo "[Warn] Sorry, but we don't have your plugin's download url. Please wait for support~"
    fi
    echo "[Info] Downloading ${pluginName}"
    wget $url >/dev/null 2>/dev/null
    isPlugin=true
}
#systemUpdate
function systemUpdate(){
    if [[ $@ =~ 'nosudo' ]]; then
        if [ ${packageManager} = apt ]; then
            echo "[Info] Updating using apt..."
            apt -y full-upgrade
        elif [ ${packageManager} = dnf ]; then
            echo "[Info] Updating using dnf..."
            dnf -y update
        elif [ ${packageManager} = pacman ]; then
            echo "[Info] Updating using pacman..."
            pacman --noconfirm -Syyu
        else
            unset packageManager
            echo "[Critical] Package manager not found!"
            exitScript 5
        fi
    else
        if [ ${packageManager} = apt ]; then
            echo "[Info] Updating using apt..."
            sudo apt -y full-upgrade
        elif [ ${packageManager} = dnf ]; then
            echo "[Info] Updating using dnf..."
            sudo dnf -y update
        elif [ ${packageManager} = pacman ]; then
            echo "[Info] Updating using pacman..."
            sudo pacman --noconfirm -Syyu
        else
            unset packageManager
            exitScript 5
        fi
    fi
}

#buildPaper
function buildPaper(){
    while [ ! -f paper-*.jar ]; do
        export build=`expr ${build} - 1`
        echo "[Info] Testing build ${build}"
        url="https://papermc.io/api/v2/projects/paper/versions/${version}/builds/${build}/downloads/paper-${version}-${build}.jar"
        wget $url >/dev/null 2>/dev/null
    done
    echo "[Info] Downloaded build ${build}."
    if [ -f paper-*.jar ]; then
        mv paper-*.jar Paper-latest.jar
    fi
    export isPlugin=false
    export checkFile=Paper-latest.jar
    integrityProtect
    versionCompare
    if [ $? = 0 ]; then
        echo "[Info] You're up to date."
        clean
    else
        echo "[Info] Updating Paper..."
        update Paper-latest.jar
    fi
    clean
}

#32-bit Warning
function checkBit(){
    getconf LONG_BIT >/dev/null 2>/dev/null
    return $?
    if [ $? = 64 ]; then
        echo "[Info] Running on 64-bit system."
    elif [ $? = 32 ]; then
        if [[ $@ =~ "unsafe" ]]; then
            echo "[Warn] Running on 32-bit system may encounter unexpected problems."
        else
            exitScript 3
        fi
    fi
}

function updateMain(){
    if [[ $@ =~ 'newserver' ]]; then
        createFolder $@
    fi

    echo "[Info] Starting auto update at `date`"
    cd ${serverPath}/Update/
    if [[ $@ =~ "paper" ]]; then
        buildPaper
    fi

    if [[ $@ =~ "spigot" ]]; then
        buildSpigot
    fi

    if [[ $@ =~ 'mojang' ]]; then
        buildMojang
    fi
    if [[ $@ =~ "mtvehicles" ]]; then
        isPlugin=true
        pluginUpdate MTVehicles
        checkFile="MTVehicles.jar"
        integrityProtect
        versionCompare
        update MTVehicles.jar
        clean
    fi

    if [[ $@ =~ "geyser" ]]; then
        export isPlugin=true
        pluginUpdate Geyser
        export checkFile='Geyser-Spigot.jar'
        integrityProtect
        versionCompare
        update *.jar
        clean
    fi

    if [[ $@ =~ "floodgate" ]]; then
        export isPlugin=true
        export checkFile='floodgate-spigot.jar'
        pluginUpdate Floodgate
        integrityProtect
        versionCompare
        update *.jar
        clean
    fi

    if [[ $@ =~ "sac" ]]; then
        echo "[Warn] Warning! Beta support for SoaromaSAC"
        isPlugin=true
        unset checkFile
        update *.jar
    fi


    if [[ $@ =~ 'clean' ]]; then
        cleanFile -buildTools
        cleanFile -logFiles
    fi
    ######Plugin Update End######
    if [[ $@ =~ 'system' ]]; then
        detectPackageManager $@
        systemUpdate $@
    fi
    #rm -rf ${serverPath}/plugins/BuildTools.jar #Due to a unknown bug
    clean
    echo "[Info] Job finished at `date`, have a nice day~"
    exitScript 0
}

#Start Minecraft server
function startMinecraft(){
    if [[ $@ =~ 'd' ]]; then
        checkScreen
    fi
    if [ ! -f ${serverPath} *-latest.jar ]; then
        exitScript 7
    fi
    if [[ $@ =~ 'spigot' ]]; then
        if [ -f ${serverPath}/spigot-*.jar ]; then
            mv ${serverPath}/spigot-*.jar ${serverPath}/Spigot-latest.jar
        fi
        cd ${serverPath}
        if [[ $@ =~ d ]]; then
            screenName='spigot' screenCommand='java -jar Spigot-latest.jar nogui' createScreen
        else
            java -jar Spigot-latest.jar
        fi
    elif [[ $@ =~ paper ]]; then
        if [ -f ${serverPath}/paper-*.jar ]; then
            mv ${serverPath}/paper-*.jar ${serverPath}/Paper-latest.jar
        fi
        cd ${serverPath}
        if [[ $@ =~ 'd' ]]; then
            screenName='paper' screenCommand='java -jar Paper-latest.jar nogui' createScreen
        else
            java -jar Paper-latest.jar
        fi
    elif [[ $@ =~ 'mojang' ]]; then
        if [ -f ${serverPath}/server.jar ]; then
            mv ${serverPath}/server.jar ${serverPath}/Minecraft-latest.jar
        fi
        cd ${serverPath}
        if [[ $@ =~ 'd' ]]; then
            screenName='minecraft' screenCommand='java -jar Minecraft-latest.jar nogui' createScreen
        else
            java -jar Minecraft-latest.jar
        fi
    fi
}

######Function End######
if [[ ! $@ ]]; then
    echo "[Info] Hello! `whoami` at `date`"
    printCopyright
    exit 0
fi
echo "[Info] Hello! `whoami` at `date`"
printCopyright
checkBit
echo "[Info] Reading settings"
clean 1>/dev/null 2>/dev/null
checkConfig
if [[ $@ =~ 'install' ]]; then
    installScript
    exit 0
fi
if [[ $@ =~ 'uninstall' ]]; then
    uninstallScript
    uninstallService
if [[ $@ =~ 'autostart' ]]; then
    createStartupService $@
    exit 0
fi
if [[ $@ =~ "instreq" ]]; then
    installRequirements $@
fi
if [[ $@ =~ update ]]; then
    if [[ $@ =~ "unattended" ]]; then
        updateMain $@ -nosudo 1>>${log} 2>>${log_error}
        mergeBuildToolsLog
    else
        updateMain $@
    fi
fi

if [[ $@ =~ clean ]]; then
    cleanFile buildTools
    cleanFile log
fi

if [[ $@ =~ startminecraft ]]; then
    if [[ $@ = 'unattended' ]]; then
        startMinecraft $@ d
    else
        startMinecraft $@
    fi
fi