
clear

tags=$( git describe --tags `git rev-list --tags --max-count=6`); echo -e  "$tags\n--------------------\n"; for t in ${tags[@]}; do echo -e "$t"; [[ ! -d ../$t ]] && (echo -e "\tnew\n"; mkdir ../$t) ;  done

#git log --tags --simplify-by-decoration --pretty="format:%ai %s" | egrep -i 'community' | egrep -i 'gold' | head -n 3
