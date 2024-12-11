#!/bin/bash

VERSION="1.3"
TARGET=$1
WORKING_DIR=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
WORDLIST_PATH="$WORKING_DIR/wordlists"
RESULTS_PATH="$WORKING_DIR/results/$TARGET"
SUB_PATH="$RESULTS_PATH/subdomain"
CORS_PATH="$RESULTS_PATH/cors"
IP_PATH="$RESULTS_PATH/ip"
PSCAN_PATH="$RESULTS_PATH/portscan"
SSHOT_PATH="$RESULTS_PATH/screenshot"
DIR_PATH="$RESULTS_PATH/directory"

RED="\033[1;31m"
GREEN="\033[1;32m"
BLUE="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

displayLogo() {
    echo -e " █████╗ ██╗   ██╗████████╗ ██████╗     ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗
 ██╔══██╗██║   ██║╚══██╔══╝██╔═══██╗    ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║
 ███████║██║   ██║   ██║   ██║   ██║    ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║
 ██╔══██║██║   ██║   ██║   ██║   ██║    ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║
 ██║  ██║╚██████╔╝   ██║   ╚██████╔╝    ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║
 ╚═╝  ╚═╝ ╚═════╝    ╚═╝    ╚═════╝     ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
 ദ്ദി ˉ͈̀꒳ˉ͈́ )✧"
}

checkArgs() {
    if [[ $# -eq 0 ]]; then
        echo -e "${RED}[+] Usage:${RESET} $0 <domain>\n"
        exit 1
    fi
}

# Tambahkan fungsi ini sebelum fungsi utama lainnya
checkAndInstallTools() {
    echo -e "${GREEN}--==[ Checking and Installing Tools ]==--${RESET} (^..^)ﾉ"

    # Tools yang akan dicek
    tools=("amass" "subfinder" "subjack" "massdns" "masscan" "nmap" "xsltproc" "aquatone" "dirsearch")

    # Loop untuk memeriksa keberadaan tools
    for tool in "${tools[@]}"; do
        if ! command -v $tool &> /dev/null; then
            echo -e "${YELLOW}[!] $tool not found. Installing...${RESET}"
            
            case $tool in
                amass)
                    sudo apt-get install -y amass
                    ;;
                subfinder)
                    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
                    cd ~/go/bin && chmod +x subfinder
                    sudo mv subfinder /usr/local/bin
                    ;;
                subjack)
                    go install -v github.com/haccer/subjack@latest
                    cd ~/go/bin && chmod +x subjack
                    sudo mv subjack /usr/local/bin
                    ;;
                massdns)
                    sudo apt-get install -y massdns
                    ;;
                masscan)
                    sudo apt-get install -y masscan
                    ;;
                nmap)
                    sudo apt-get install -y nmap
                    ;;
                xsltproc)
                    sudo apt-get install -y xsltproc
                    ;;
                aquatone)
                    go install -v github.com/michenriksen/aquatone@latest
                    cd ~/go/bin && chmod +x aquatone
                    sudo mv aquatone /usr/local/bin
                    ;;
                dirsearch)
                    sudo apt-get install -y dirsearch
                    ;;
                *)
                    echo -e "${RED}[-] Installer for $tool not defined. Please install it manually.${RESET} (╥﹏╥)"
                    ;;
            esac
        else
            echo -e "${BLUE}[+] $tool is already installed.${RESET} PIW PIW ദ്ദി(˵ •̀ ᴗ - ˵ ) ✧"
        fi
    done
}


setupDir() {
    echo -e "${GREEN}--==[ Setting things up ]==--${RESET}"
    echo -e "${RED}\n[+] Creating results directories...${RESET}"
    rm -rf $RESULTS_PATH
    mkdir -p $SUB_PATH $CORS_PATH $IP_PATH $PSCAN_PATH $SSHOT_PATH $DIR_PATH
    echo -e "${BLUE}[*] $SUB_PATH${RESET}"
    echo -e "${BLUE}[*] $CORS_PATH${RESET}"
    echo -e "${BLUE}[*] $IP_PATH${RESET}"
    echo -e "${BLUE}[*] $PSCAN_PATH${RESET}"
    echo -e "${BLUE}[*] $SSHOT_PATH${RESET}"
    echo -e "${BLUE}[*] $DIR_PATH${RESET}"
}

enumSubs() {
    echo -e "${GREEN}\n--==[ Enumerating subdomains ]==--${RESET}"
    echo -e "${RED}[+] Running Amass...${RESET}"
    amass enum -d $TARGET -o $SUB_PATH/amass.txt

    echo -e "${RED}[+] Running Subfinder...${RESET}"
    subfinder -d $TARGET -t 50 -w dns_all.txt --silent -o $SUB_PATH/subfinder.txt

    echo -e "${RED}\n[+] Combining subdomains...${RESET}"
    cat $SUB_PATH/*.txt | sort | awk '{print tolower($0)}' | uniq > $SUB_PATH/final-subdomains.txt
    echo -e "${BLUE}[*] Check the list of subdomains at $SUB_PATH/final-subdomains.txt${RESET}"
}

corsScan() {
    echo -e "${GREEN}\n--==[ Checking CORS configuration ]==--${RESET}"
    echo -e "${RED}[+] Running CORScanner...${RESET}"
    python3 CORScanner/cors_scan.py -v -t 50 -i $SUB_PATH/final-subdomains.txt | tee $CORS_PATH/final-cors.txt
    echo -e "${BLUE}[*] Check the result at $CORS_PATH/final-cors.txt${RESET}"
}

enumIPs() {
    echo -e "${GREEN}\n--==[ Resolving IP addresses ]==--${RESET}"
    echo -e "${RED}[+] Running MassDNS...${RESET}"
    massdns -r resolvers.txt -q -t A -o S -w $IP_PATH/massdns.raw $SUB_PATH/final-subdomains.txt
    cat $IP_PATH/massdns.raw | grep -e ' A ' | cut -d 'A' -f 2 | tr -d ' ' > $IP_PATH/massdns.txt
    cat $IP_PATH/*.txt | sort -V | uniq > $IP_PATH/final-ips.txt
    echo -e "${BLUE}[*] Check the list of IP addresses at $IP_PATH/final-ips.txt${RESET}"
}

portScan() {
    echo -e "${GREEN}\n--==[ Port-scanning targets ]==--${RESET}"
    echo -e "${RED}[+] Running Masscan...${RESET}"
    sudo masscan -p 1-65535 --rate 10000 --wait 0 --open -iL $IP_PATH/final-ips.txt -oX $PSCAN_PATH/masscan.xml
    echo -e "${RED}[+] Running Nmap...${RESET}"
    sudo nmap -sVC -p $(cat $PSCAN_PATH/masscan.xml | grep portid | cut -d "\"" -f 10 | sort -n | uniq | paste -sd,) --open -v -T4 -Pn -iL $SUB_PATH/final-subdomains.txt -oX $PSCAN_PATH/nmap.xml
    echo -e "${BLUE}[*] Nmap Done! Check the XML report at $PSCAN_PATH/nmap.xml${RESET}"
}

visualRecon() {
    echo -e "${GREEN}\n--==[ Taking screenshots ]==--${RESET}"
    echo -e "${RED}[+] Running Aquatone...${RESET}"
    cat $SUB_PATH/final-subdomains.txt | aquatone -http-timeout 10000 -scan-timeout 300 -ports xlarge -out $SSHOT_PATH/
    echo -e "${BLUE}[*] Check the result at $SSHOT_PATH/aquatone_report.html${RESET}"
}

bruteDir() {
    echo -e "${GREEN}\n--==[ Bruteforcing directories ]==--${RESET}"
    echo -e "${RED}[+] Running Dirsearch...${RESET}"
    mkdir -p $DIR_PATH/dirsearch
    for url in $(cat $SSHOT_PATH/aquatone_urls.txt); do
        fqdn=$(echo $url | sed -e 's;https\?://;;' | sed -e 's;/.*$;;')
        dirsearch -u $url -e php,asp,aspx,jsp,html,zip,jar,sql -x 500,503 -r -w $WORDLIST_PATH/raft-large-words.txt --plain-text-report=$DIR_PATH/dirsearch/$fqdn.txt
    done
    echo -e "${BLUE}[*] Check the results at $DIR_PATH/dirsearch/${RESET}"
}

# Main Execution
displayLogo
checkArgs $TARGET
setupDir
enumSubs
corsScan
enumIPs
portScan
visualRecon
bruteDir

echo -e "${GREEN}\n--==[ DONE ]==--${RESET}"
