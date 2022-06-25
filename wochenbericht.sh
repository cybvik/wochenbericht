#!/bin/bash

#  ______   ________     _____ _  __  
# / ___\ \ / / __ ) \   / /_ _| |/ /  Author: cybvik
#| |    \ V /|  _ \\ \ / / | || ' /   Email: mail@cybvik.xyz
#| |___  | | | |_) |\ V /  | || . \   Repo: git.cybvik.xyz/wochenbericht
# \____| |_| |____/  \_/  |___|_|\_\  

### VARIABLES

script_dir="$(dirname $(realpath $0))"
tex_dir="$script_dir/tex"
out_dir="$script_dir/out"
user_data="$script_dir/user.csv"

### FUNCTIONS

check_dir() {
	[ -d "$1" ] || mkdir -p "$1"
}

read_data() {
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

get_data() {
  name="$(dialog --inputbox "Name des Auszubildenden:" 0 0 --output-fd 1)"
  train_year="$(dialog --inputbox "Ausbildungsjahr:" 0 0 --output-fd 1)"
  cal_year="$(dialog --inputbox "Kalenderjahr des Berichts:" 0 0 --output-fd 1)"
  cal_week="$(dialog --inputbox "Kalenderwoche des Berichts:" 0 0 --output-fd 1)"
}

get_department() {
  department="$(dialog --inputbox "Abteilung:" 0 0 --output-fd 1)"
}

get_confirmation() {
  dialog --yesno  "Name: $name\nAusbildungsjahr: $train_year\nKalenderwoche: $cal_week\nKalenderjahr: $cal_year\nAbteilung: $department\nWoche: $date_range\n\n Sind die Angaben korrekt?" 0 0 --output-fd 1
  response=$?
}

write_data() {
  echo -e "NAME,$name\nTRAIN_YEAR,$train_year\nCAL_YEAR,$cal_year\nCAL_WEEK,$cal_week" > "$user_data"
}

get_date_range() {
  local week=$1 year=$2
  local week_num_of_Jan_1 week_day_of_Jan_1
  local first_Mon
  local date_fmt="+%d.%m.%Y"
  local mon sun

  week_num_of_Jan_1=$(date -d $year-01-01 +%W)
  week_day_of_Jan_1=$(date -d $year-01-01 +%u)

  if ((week_num_of_Jan_1)); then
    first_Mon=$year-01-01
  else
    first_Mon=$year-01-$((01 + (7 - week_day_of_Jan_1 + 1) ))
  fi

  mon=$(date -d "$first_Mon +$((week - 1)) week" "$date_fmt")
  sun=$(date -d "$first_Mon +$((week - 1)) week + 6 day" "$date_fmt")
  date_range="$mon - $sun"
}

prep_template() {
  current_tex="$tex_dir/history/$cal_year/$cal_week"
  mkdir -p "$current_tex" || { clear; echo "Error! Could not create directory for .tex files"; exit 1 ;}
  cp "$tex_dir/template/wochenbericht.tex" "$current_tex/wochenbericht.tex"
  sed -i "s/NAME/$name/" "$current_tex/wochenbericht.tex"
  sed -i "s/WOCHE/$date_range/" "$current_tex/wochenbericht.tex"
  sed -i "s/AUSBILDUNGSJAHR/$train_year/" "$current_tex/wochenbericht.tex"
  sed -i "s/ABTEILUNG/$department/" "$current_tex/wochenbericht.tex"
}

vipe_cmd() {
  echo "$1 (DIESE ZEILE LÖSCHEN!)" | vipe > "$current_tex/$2.tex"
}

compile() {
  cd "$current_tex"
  pdflatex --output-directory "$out_dir" --jobname "$cal_year-$cal_week" "wochenbericht.tex"
  rm "$out_dir"/*.aux "$out_dir"/*.log
}

post_compile() {
  if [ "$cal_week" == 52 ]; then
    cal_week="1"
    ((cal_year=cal_year+1))
    sed -i "s/CAL_WEEK.*/CAL_WEEK,$cal_week/" "$user_data"
    sed -i "s/CAL_YEAR.*/CAL_YEAR,$cal_year/" "$user_data"
  else
    ((cal_week=cal_week+1))
    sed -i "s/CAL_WEEK.*/CAL_WEEK,$cal_week/" "$user_data"
  fi
}

### SCRIPT

dialog --msgbox "Willkommen im Wochenberichtsskript!" 0 0 --output-fd 1 || { clear; echo "Error! You need dialog to run this script!"; exit 1; }

check_dir "$tex_dir"
check_dir "$out_dir"

[ -f "$user_data" ] && read_data || get_data
get_department
get_date_range "$cal_week" "$cal_year"
while true; do
  get_confirmation
  [ "$response" == 0 ] && break || { get_data; get_department; get_date_range; }
  write_data
done
write_data
prep_template
vipe_cmd "Betriebliche Tätigkeiten" betrieb
vipe_cmd "Außeretriebliche Tätigkeiten" extern
vipe_cmd "Berufsschule" schule
compile
post_compile
