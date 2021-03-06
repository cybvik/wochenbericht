#!/bin/bash

#  ______   ________     _____ _  __  
# / ___\ \ / / __ ) \   / /_ _| |/ /  Author: cybvik
#| |    \ V /|  _ \\ \ / / | || ' /   Email: mail@cybvik.xyz
#| |___  | | | |_) |\ V /  | || . \   Repo: git.cybvik.xyz/wochenbericht
# \____| |_| |____/  \_/  |___|_|\_\  

### VARIABLES
# Determine the locations the script needs to know
script_dir="$(dirname $(realpath $0))"
tex_dir="$script_dir/tex"
out_dir="$script_dir/out"
user_data="$script_dir/user.csv"

### FUNCTIONS

read_data() { # Get the values from user.csv
  while IFS=, read -r key value; do
    case "$key" in
      "NAME") name="$value" ;;
      "TRAIN_YEAR") train_year="$value" ;;
      "CAL_YEAR") cal_year="$value" ;;
      "CAL_WEEK") cal_week="$value" ;;
      *) ;;
    esac
  done < "$user_data"
}

get_data() { # Get data via user input
  name="$(dialog --inputbox "Name des Auszubildenden:" 0 0 --output-fd 1)"
  train_year="$(dialog --inputbox "Ausbildungsjahr:" 0 0 --output-fd 1)"
  cal_year="$(dialog --inputbox "Kalenderjahr des Berichts:" 0 0 --output-fd 1)"
  cal_week="$(dialog --inputbox "Kalenderwoche des Berichts:" 0 0 --output-fd 1)"
}

get_department() { # Department gets an extra function because it is not saved in user.csv
  department="$(dialog --inputbox "Abteilung:" 0 0 --output-fd 1)"
}

get_date_range() { # Function that determines the first and last day of the chosen week
  local first_Mon
  local date_fmt="+%d.%m.%Y"
  local mon sun

  if (($(date -d $cal_year-01-01 +%W))); then
    first_Mon=$cal_year-01-01
  else
    first_Mon=$cal_year-01-$((01 + (7 - $(date -d $cal_year-01-01 +%u) + 1) ))
  fi

  mon=$(date -d "$first_Mon +$(($cal_week - 1)) week" "$date_fmt")
  sun=$(date -d "$first_Mon +$(($cal_week - 1)) week + 6 day" "$date_fmt")
  date_range="$mon - $sun"
}

vipe_cmd() { # Helper function to call vipe
  echo "$1 (DIESE ZEILE LÖSCHEN!)" | vipe > "$current_tex/$2.tex"
}

### SCRIPT
dialog --msgbox "Willkommen im Wochenberichtsskript!" 0 0 --output-fd 1 || { clear; echo "Error! You need dialog to run this script!"; exit 1; }

for i in "$tex_dir" "$out_dir"; do
  [ -d "$i" ] || mkdir -p "$i"
done

while true; do
  [ -f "$user_data" ] && read_data || get_data
  get_department
  get_date_range "$cal_week" "$cal_year"

  # Let user validate inputs, let him redo the inputs if something is wrong
  while true; do
    dialog --yesno  "Name: $name\nAusbildungsjahr: $train_year\nKalenderwoche: $cal_week\nKalenderjahr: $cal_year\nAbteilung: $department\nWoche: $date_range\n\n Sind die Angaben korrekt?" 0 0 --output-fd 1
    case "$?" in
      '0' ) break ;;
      '1' ) get_data; get_department; get_date_range ;;
      * ) clear; exit 1 ;;
    esac
  done

  # Write the current data to user.csv
  echo -e "NAME,$name\nTRAIN_YEAR,$train_year\nCAL_YEAR,$cal_year\nCAL_WEEK,$cal_week" > "$user_data"

  # Copy template and insert data into copied file
  current_tex="$tex_dir/history/$cal_year/$cal_week"
  mkdir -p "$current_tex" || { clear; echo "Error! Could not create directory for .tex files"; exit 1 ;}
  cp "$tex_dir/template/wochenbericht.tex" "$current_tex/wochenbericht.tex"
  sed -i "s/NAME/$name/" "$current_tex/wochenbericht.tex"
  sed -i "s/WOCHE/$date_range/" "$current_tex/wochenbericht.tex"
  sed -i "s/AUSBILDUNGSJAHR/$train_year/" "$current_tex/wochenbericht.tex"
  sed -i "s/ABTEILUNG/$department/" "$current_tex/wochenbericht.tex"

  # Use vipe to let user enter their report text
  vipe_cmd "Betriebliche Tätigkeiten" betrieb
  vipe_cmd "Außeretriebliche Tätigkeiten" extern
  vipe_cmd "Berufsschule" schule

  # Compile via pdflatex, remove *.log and *.aux files
  cd "$current_tex"
  pdflatex --output-directory "$out_dir" --jobname "$cal_year-$cal_week" "wochenbericht.tex"
  rm "$out_dir"/*.aux "$out_dir"/*.log

  # Increment cal_week and check if it was the last week of the year
  if [ "$cal_week" == 52 ]; then
    cal_week="1"
    ((cal_year=cal_year+1))
    sed -i "s/CAL_WEEK.*/CAL_WEEK,$cal_week/" "$user_data"
    sed -i "s/CAL_YEAR.*/CAL_YEAR,$cal_year/" "$user_data"
  else
    ((cal_week=cal_week+1))
    sed -i "s/CAL_WEEK.*/CAL_WEEK,$cal_week/" "$user_data"
  fi

  # Ask user if he wants to create the next report as well
  dialog --yesno "Noch einen Bericht erstellen?" 0 0 --output-fd 1
  case "$?" in
    '0' ) break ;;
    '1' ) clear; exit 1 ;;
    * ) clear; exit 1 ;;
  esac
done

