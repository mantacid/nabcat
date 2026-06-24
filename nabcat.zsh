#!/usr/bin/zsh

if [ -z "$(command -v gum)" ]; then
  echo "ERROR: dependency gum not satisfied."
  exit 1
fi

if [ -z "$(command -v yq)" ]; then
  echo "ERROR: dependency yq not satisfied."
  exit 1
fi

declare -g flag_disable_clipboard

case $XDG_SESSION_TYPE in
  wayland)
    [ -z "$(command -v wl-copy)" ] && gum log -s -l warn "Dependency 'wl-clipboard' not met. Clipboard functionality will not work."
    flag_disable_clipboard=1
  ;;
  x11)
    [ -z "$(command -v xsel)" ] && gum log -s -l warn "Dependency 'xsel' not satisfied. Clipboard function will not work."
    flag_disable_clipboard=1
  ;;
  *)
    gum log -s -l error "Unrecognized display server: $XDG_SESSION_TYPE."
    flag_disable_clipboard=1
  ;;
esac

declare -g env_version="3.2.2"

declare -g conf_path=$HOME/.config/nabcat.yaml
if [ ! -f $conf_path ]; then
  <<EOF > $conf_path
env:
  cat-dir: "$HOME/Pictures/Cats/"
  do-copy: true
  verbose: false
  return-found: true
backend-defs:
  clipboard:
    - &wayland wl-copy <
    - &x11 xsel --selection --clipboard -t image/png -i
  viewer:
    - &viu viu -w 30
  picker:
    - &gum gum filter
    - &fzf fzf --style=full --preview="icat -m 24bit -w 50 $(echo $env_cat_dir){}"
backends:
  clipboard: *$XDG_SESSION_TYPE
  viewer: *viu
  picker: *fzf
EOF
fi

function read_config() {
  
  declare -g env_prog_clipboard=$(yq e -o shell '.backends.clipboard' $conf_path | sed 's|value=||g' | sed "s|'||g")
  declare -g env_prog_viewer=$(yq e -o shell '.backends.viewer' $conf_path | sed 's|value=||g' | sed "s|'||g")
  declare -g env_prog_picker=$(yq e -o shell '.backends.picker' $conf_path | sed 's|value=||g' | sed "s|'||g")
  declare -g env_cat_dir=$(yq '.env.cat-dir' $conf_path)
  case $(yq e '.env.do-copy' $conf_path) in
    true)
      declare -g flag_do_copy=1
    ;;
    *)
      declare -g flag_do_copy
    ;;
  esac

  case $(yq e '.env.verbose' $conf_path) in
    true)
      declare -g flag_verbose=1
    ;;
    *)
      declare -g flag_verbose
    ;;
  esac

  case $(yq e '.env.return-found' $conf_path) in
    true)
      declare -g flag_return_result=1
    ;;
    *)
      declare -g flag_return_result
    ;;
  esac
}

declare -g env_clipboard_command
declare -g var_catpath
declare -g flag_do_copy=1
## check if nabcat directory is specified in environment variable. if not, fallback to default.
if [ $NABCAT_CAT_DIR ]; then
  if [ -z $env_cat_dir ]; then
    gum log -s -l warn "Environment variable NABCAT_CAT_DIR depreciated as of 3.0.0, and the value was not found in $conf_path."
    exit 7
  fi
fi
declare -g env_picker="gum filter"
declare -g flag_verbose
declare -g flag_return_result
declare -g flag_do_file_overwrite

function nabcat_main() {
  read_config
  
  if [ $# -eq 0 ]; then
  	thatcat=$(nabcat_choose -cr)
    if [ -z "$(echo $thatcat | grep -Po '\/$')" ]; then
      if [ ! -z "$(command -v viu)" ]; then
        eval $(echo "$env_prog_viewer \"$thatcat\"")
        
      	#viu -w 30 "$thatcat"
      fi
      gum log -s -l info "Copied \"$(echo $thatcat | grep -Po '(?<=\/)[a-zA-Z0-9\-_\s]+(?=\.)')\" to clipboard"
    else
      exit 0
    fi
    exit 0
  fi
  case $1 in
    get)
      shift
      nabcat_get $@
    ;;
    choose)
      shift
      nabcat_choose $@
    ;;
    save)
      shift
      nabcat_save $@
    ;;
    list)
      shift
      nabcat_list $@
    ;;
    info)
      shift
      nabcat_info $@
    ;;
    random)
      shift
      nabcat_random $@
    ;;
    help)
      shift
      nabcat_help $@
    ;;
    *)
      gum log -s -l fatal "Unrecognized command: $1"
    ;;
  esac
}

function nabcat_info() {
  
  declare flag_V
  declare flag_y
  while getopts "Vy" opts; do
	case $opts in
	  V)
	    flag_V="true"
	  ;;
	  y)
	    flag_y="true"
	  ;;
	  *)
	  	exit 3
	  ;;
	esac
  done

  [ -z $flag_V ] || echo "$env_version"
  [ -z $flag_y ] || yq e '.' $conf_path
  exit 0
}

function nabcat_random() {
  while getopts "d:vcC" opts; do
    case $opts in
      d)
        env_cat_dir="$OPTARG"
      ;;
      v)
        flag_verbose=1
      ;;
      c)
      	flag_do_copy=1
      ;;
      C)
      	unset -v flag_do_copy
      ;;
      *)
      exit 3
      ;;
    esac
  done
  ## choose randomly from env_cat_dir
  retval="$env_cat_dir$(ls $env_cat_dir | shuf -n 1)"
  catname=$(echo "$retval" | grep -Po '(?<=\/)[a-zA-Z0-9\-_\s]+(?=\.)')
  [ $flag_verbose ] && gum log -s -l info "Retrieved $catname."
  if [ $flag_do_copy ]; then
    eval $(echo "$env_prog_clipboard \"$retval\"")
	gum log -s -l info "Copied \"$catname\" to clipboard."
  fi
  echo "$retval"
}

## BUG: won't save from searXNG image proxy links.
function nabcat_save() {
  while getopts "d:vrO" opts; do
    case $opts in
      d)
        env_cat_dir="$OPTARG"
      ;;
      v)
        flag_verbose=1
      ;;
      r)
        flag_return_result=1
      ;;
      O)
        flag_do_file_overwrite=1
      ;;
      *)
        exit 3
      ;;
    esac
  done
  shift $(($OPTIND - 1))
  newname="$1"
  data_source="$2"
  if [ $flag_do_file_overwrite ]; then
    [ $flag_verbose ] && gum log -s -l info "Writing cat into file: $env_cat_dir$1"
    eval "$data_source" > $env_cat_dir$newname
  else
    # check if we will overwrite
    if [ -z $(ls $env_cat_dir | grep -Po "^$1") ]; then
      # no prablem. write it.
      [ $flag_verbose ] && gum log -s -l info "Writing cat into file: $env_cat_dir$1"
      eval "$data_source" > $env_cat_dir$newname
    else
      gum log -s -l warn "File $1 exists at $env_cat_dir. To overwrite this file, run the command with the -O flag."
      exit 4
    fi
  fi
}

function nabcat_list() {
  while getopts "d:" opts; do
    case $opts in
      d)
        env_cat_dir="$OPTARG"
      ;;
      *)
        exit 3
      ;;
    esac
  done
  \ls "$env_cat_dir"
}

function nabcat_choose() {
  while getopts "d:cCP:vr" opts; do
    case $opts in
      d)
        env_cat_dir="$OPTARG"
      ;;
      c)
        [ $flag_disable_clipboard ] && flag_do_copy=1
        [ $flag_disable_clipboard ] ||  gum log -s -l warn "Clipboard functionality disabled due to lack of required dependency."
      ;;
      C)
        unset -v flag_do_copy
      ;;
      P)
        env_prog_picker="$OPTARG"
      ;;
      v)
        flag_verbose=1
      ;;
      r)
        flag_return_result=1
      ;;
      *)
        exit 3
      ;;
    esac
  done
  
  cmd="ls $env_cat_dir | $env_prog_picker"
  var_catpath="$env_cat_dir$(eval $cmd)"
  ## prevent sending all cats in folder to output.
  catname=$(echo "$var_catpath" | grep -Po '(?<=\/)[a-zA-Z0-9\-_\s]+(?=\.)')
  if [ -z "$catname" ]; then
  	exit 0
  fi
  
  [ $flag_verbose ] && gum log -s -l info "Retrieved cat: $catname"

  if [ $flag_do_copy ]; then
    if [ $flag_verbose ]; then
      gum log -s -l info "Copied \"$catname\" to clipboard."
    fi
    case "$XDG_SESSION_TYPE" in
      wayland)
        wl-copy < $var_catpath
      ;;
      x11)
      ##BUG: only works with PNGs. This is an upstream issue.
        xsel --selection --clipboard -t image/png -i "$var_catpath"
      ;;
      *)
        echo "Display server not recognized. Expected either 'wayland' or 'x11', got \"$XDG_SESSION_TYPE\""
        return 2
      ;;
    esac
  fi
  
  if [ $flag_return_result ]; then
    [ -z "$var_catpath" ] || echo "$var_catpath"
  fi
}

function nabcat_get() {
  while getopts "d:cCv" opts; do
    case $opts in
      d)
        env_cat_dir="$OPTARG"
      ;;
      c)
        [ $flag_disable_clipboard ] && flag_do_copy=1
        [ $flag_disable_clipboard ] || gum log -s -l warn "Clipboard functionality disabled due to lack of required dependency."
      ;;
      C)
        unset -v flag_do_copy
      ;;
      v)
        flag_verbose=1
      ;;
      *)
        exit 3
      ;;
    esac
  done
  shift $(($OPTIND - 1))
  ## copy logic
  var_catpath="$env_cat_dir$1.png"
  if [ ! -f "$var_catpath" ]; then
    gum log -s -l error "Cat \"$1\" not found in $env_cat_dir."
    exit 4
  fi
  
  if [ $flag_do_copy ]; then
    if [ $flag_verbose ]; then
      catname=$(echo "$var_catpath" | grep -Po '(?<=\/)[a-zA-Z0-9\-_\s]+(?=\.)')
      gum log -s -l info "Copied \"$catname\" to clipboard."
    fi
    eval $(echo "$env_prog_clipboard \"$var_catpath\"")
  fi
  ## output catpath for use in scripts. need a way to give completions.
  
  flag_return_result=1
  echo "$var_catpath"
}

function _choose_help() {
  
  declare -A flagarray_choose=( ["-c"]="Copy the selected cat to the clipboard. This is the default behavior." ["-C"]="Do not copy result to clipboard." ["-P STRING"]="Command into which the list of files will be piped to allow for interactive selection. Default value is 'gum filter'" ["-d PATH"]="Override the location in which to search for cats. Default value is $env_cat_dir. MUST INCLUDE TRAILING SLASH!" ["-r"]="Output the path to the selected cat after the command exits. Useful for passing the result to an image viewer." ["-v"]="Verbose output." )
  
  echo "CHOOSE: Interactively select a cat."
  echo "usage: nabcat choose [-cCvr] [-P STRING] [-d PATH]"
  echo -e "\n Flags:"
  for key in ${(k)flagarray_choose}; do
    printf '  %s\t%s\n' "$key" "$flagarray_choose[$key]" | expand -t 15
  done
  
}

function _get_help() {
  
  declare -A flagarray_get=( ["-c"]="Copy the selected cat to the clipboard. This is the default behavior." ["-C"]="Do not copy result to clipboard." ["-d"]="Override the location in which to search for cats. Default value is $env_cat_dir. MUST INCLUDE TRAILING SLASH!" ["-r"]="Output the path to the selected cat after the command exits. Useful for passing the result to an image viewer." ["-v"]="Verbose output." )
  declare -A argsarray_get=( ["FILENAME"]="The file name of the cat you wish to get, without the extension." )
  
  echo "GET: Pass a name of a cat to get that cat."
  echo "usage: nabcat get [-d PATH] [-cCvr] FILENAME"
  echo -e "\nArguments:"
  for key in ${(k)argsarray_get}; do
    printf '  %s\t%s\n' "$key" "$argsarray_get[$key]" | expand -t 15
  done
  echo -e "\nFlags:"
  for key in ${(k)flagarray_get}; do
    printf '  %s\t%s\n' "$key" "$flagarray_get[$key]" | expand -t 15
  done
}

function _random_help() {
  declare -A flagtable_random=( ["-d PATH"]="Override the location in which to search for cats. Default value is $env_cat_dir. MUST INCLUDE TRAILING SLASH!" ["-v"]="Verbose output." ["-c"]="Copy the selected cat to the clipboard. This is the default behavior." ["-C"]="Do not copy result to clipboard." )
  
  echo "RANDOM: Returns the path to a random cat."
  echo "usage: nabcat random [-d PATH] [-v]"
  echo -e "\nFlags:"
  for key in ${(k)flagtable_random}; do
    printf '  %s\t%s\n' "$key" "$flagtable_random[$key]" | expand -t 15
  done
}

function _save_help() {
  declare -A argsarray_save=( ["NEWNAME"]="Name of the newly created file, including the extension." ["SOURCE"]="Expression or command substitution that outputs the file data of a remote cat." )
  
  declare -A flagarray_save=( ["-d PATH"]="Override the location in which to search for cats. Default value is $env_cat_dir. MUST INCLUDE TRAILING SLASH!" ["-O"]="Overwrite files if they already exist. Disabled by default." ["-r"]="Output the path to the selected cat after the command exits. Useful for passing the result to an image viewer." ["-v"]="Verbose output." )
  
  echo "SAVE: save a cat from a source to a file of your choosing within the cats folder."
  echo "usage: nabcat save [-d path] [-vrO] NEWNAME SOURCE"
  echo -e "\nArguments:"
  for key in ${(k)argsarray_save}; do
    printf '  %s\t%s\n' "$key" "$argsarray_save[$key]" | expand -t 15
  done
  echo -e "\nFlags:"
  for key in ${(k)flagarray_save}; do
    printf '  %s\t%s\n' "$key" "$flagarray_save[$key]" | expand -t 15
  done
}

function _list_help() {
  
  declare -A flagarray_list=( ["-d PATH"]="Override the location in which to search for cats. Default value is $env_cat_dir" )
  echo "LIST: list contents of the cats directory."
  echo "usage: nabcat list [-d PATH]"
  echo -e "\nFlags:"
  for key in ${(k)flagarray_list}; do
    printf '  %s\t%s\n' "$key" "$flagarray_list[$key]" | expand -t 15
  done
}

function _info_help() {
    declare -A flagarray_info=( ["-V"]="Show the version." ["-y"]="Show the current config" )
	
	echo "INFO: Show available features and version."
    echo "usage: nabcat info [-Vy]"
    echo -e "\nFlags:"
	for key in ${(k)flagarray_info}; do
    printf '  %s\t%s\n' "$key" "$flagarray_info[$key]" | expand -t 15
  done
}

function nabcat_help() {
  ## check $1 for name of command
  if [ -z "$1" ]; then
    ## if none found, print general help
    
    echo "nabcat: quickly find cat images and send them to the clipboard for posting."
    echo "       nabcat choose [-cCvr] [-P STRING] [-d PATH]"
    echo "       nabcat get [-d PATH] [-cCvr] FILENAME"
    echo "       nabcat random [-d PATH] [-v]"
    echo "       nabcat save [-d path] [-vrO] NEWNAME SOURCE"
    echo "       nabcat list [-d PATH]"
    echo "       nabcat help [?COMMAND]"
    echo ""
    echo "Running the command without arguments will attempt to invoke the viewer defined in your config's backends section on the result of 'nabcat choose -cr'"
    
    echo -e "\nCOMMANDS:\n"
    _choose_help
    echo -e "\n"
    _get_help
    echo -e "\n"
    _random_help
    echo -e "\n"
    _save_help
    echo -e "\n"
    _list_help
    echo -e "\n"
    _info_help
  else
    ## if one found, print detailed help for that command.
    case "$1" in
      choose)
        _choose_help
      ;;
      get)
        _get_help
      ;;
      random)
        _random_help
      ;;
      save)
        _save_help
      ;;
      list)
        _list_help
      ;;
      info)
        _info_help
      ;;
      help)
        declare -A argsarray_help=( ["COMMAND"]="Optional. Command to show help for. Valid options include: choose, get, save, list, random, info, help" )
        
        echo "HELP: show help messages"
        echo "usage: nabcat help [COMMAND]"
        echo -e "\nArguments:"
        for key in ${(k)argsarray_help}; do
          printf '  %s\t%s\n' "$key" "$argsarray_help[$key]" | expand -t 15
        done
      ;;
      *)
        gum log -s -l warn "Command not found: $1."
      ;;
    esac
  fi
}

nabcat_main $@
