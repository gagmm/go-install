#!/bin/bash
# Author: Jrohy (改进版)
# This script installs Go in an unattended manner

# cancel centos alias
[[ -f /etc/redhat-release ]] && unalias -a

can_google=1
force_mode=0
sudo=""
os="Linux"
install_version=""
proxy_url="https://goproxy.cn"

#######color code########
red="31m"
green="32m"
yellow="33m"
blue="36m"
fuchsia="35m"

color_echo(){
    echo -e "\033[$1${@:2}\033[0m"
}

#######get params#########
while [[ $# > 0 ]]; do
    case "$1" in
        -v|--version)
            install_version="$2"
            echo -e "准备安装$(color_echo ${blue} $install_version)版本golang..\n"
            shift
            ;;
        -f)
            force_mode=1
            echo -e "强制更新golang..\n"
            ;;
        *)
            # unknown option
            ;;
    esac
    shift # past argument or value
done
#############################

ip_is_connect(){
    ping -c2 -i0.3 -W1 $1 &>/dev/null
    return $?
}

setup_env(){
    profile_path="/etc/profile"
    if [[ -z $GOPATH ]]; then
        GOPATH="/home/go"
    fi
    echo "GOPATH值为: `color_echo $blue $GOPATH`"
    echo "export GOPATH=$GOPATH" >> $profile_path
    echo 'export PATH=$PATH:$GOPATH/bin' >> $profile_path
    mkdir -p $GOPATH

    if [[ -z $(echo $PATH | grep /usr/local/go/bin) ]]; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> $profile_path
    fi
    source $profile_path
}

check_network(){
    ip_is_connect "golang.org" || can_google=0
}

setup_proxy(){
    if [[ $can_google == 0 ]]; then
        go env -w GO111MODULE=on
        go env -w GOPROXY=$proxy_url,direct
        color_echo $green "当前网络环境为国内环境, 成功设置goproxy代理!"
    fi
}

sys_arch(){
    arch=$(uname -m)
    if [[ $(uname -s) == "Darwin" ]]; then
        os="Darwin"
        vdis=$( [[ "$arch" == "arm64" ]] && echo "darwin-arm64" || echo "darwin-amd64" )
    else
        case "$arch" in
            i686|i386) vdis="linux-386" ;;
            armv7|armv6l) vdis="linux-armv6l" ;;
            armv8|aarch64) vdis="linux-arm64" ;;
            s390x) vdis="linux-s390x" ;;
            ppc64le) vdis="linux-ppc64le" ;;
            x86_64) vdis="linux-amd64" ;;
        esac
    fi
    [ $(id -u) != "0" ] && sudo="sudo"
}

install_go(){
    if [[ -z $install_version ]]; then
        echo "正在获取最新版golang..."
        count=0
        while true; do
            if [[ $can_google == 0 ]]; then
                install_version=$(curl -s --connect-timeout 15 -H 'Cache-Control: no-cache' https://go.dev/dl/ | grep -w downloadBox | grep src | grep -oE '[0-9]+\.[0-9]+\.?[0-9]*' | head -n 1)
            else
                install_version=$(curl -s --connect-timeout 15 -H 'Cache-Control: no-cache' https://github.com/golang/go/tags | grep releases/tag | grep -v rc | grep -v beta | grep -oE '[0-9]+\.[0-9]+\.?[0-9]*' | head -n 1)
            fi
            [[ ${install_version: -1} == '.' ]] && install_version=${install_version%?}
            [[ -z $install_version ]] && ((count++)) || break
            [[ $count -ge 3 ]] && { color_echo $red "\n获取go版本号失败!"; exit 1; }
        done
        echo "最新版golang: `color_echo $blue $install_version`"
    fi

    if [[ $force_mode == 0 && $(command -v go) && $(go version | awk '{print $3}' | grep -Eo "[0-9.]+") == $install_version ]]; then
        return
    fi

    file_name="go${install_version}.$vdis.tar.gz"
    local temp_path=$(mktemp -d)

    curl -H 'Cache-Control: no-cache' -L https://dl.google.com/go/$file_name -o $file_name
    tar -C $temp_path -xzf $file_name

    if [[ $? != 0 ]]; then
        color_echo $yellow "\n解压失败! 正在重新下载..."
        rm -rf $file_name
        curl -H 'Cache-Control: no-cache' -L https://dl.google.com/go/$file_name -o $file_name
        tar -C $temp_path -xzf $file_name || { color_echo $yellow "\n解压失败!"; rm -rf $temp_path $file_name; exit 1; }
    fi

    [[ -e /usr/local/go ]] && $sudo rm -rf /usr/local/go
    $sudo mv $temp_path/go /usr/local/
    rm -rf $temp_path $file_name
}

install_updater(){
    if [[ $os == "Linux" ]]; then
        echo 'source <(curl -L https://go-install.netlify.app/install.sh) $@' > /usr/local/bin/goupdate
        chmod +x /usr/local/bin/goupdate
    elif [[ $os == "Darwin" ]]; then
        cat > $HOME/go/bin/goupdate << 'EOF'
#!/bin/zsh
source <(curl -L https://go-install.netlify.app/install.sh) $@
EOF
        chmod +x $HOME/go/bin/goupdate
    fi
}

main(){
    sys_arch
    check_network
    setup_env
    install_go
    setup_proxy
    install_updater
    echo -e "golang `color_echo $blue $install_version` 安装成功!"
}

main
