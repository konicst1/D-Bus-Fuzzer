#!/bin/bash

# function to generate random argument values for a given argument signature
gen_arg() {
  local str="$1"
  local i="$2"
  local in_array="$3"
  local len="${#str}"
  local char=""
  local next_char=""
  local array_len=0
  local complex_array=0

  while [ "$i" -lt "$len" ]; do
    char="${str:i:1}"
    # Check the character at the current position in the argument signature
    case "$char" in
      "a")
        # If it's an 'a' (array), generate a random length for the array and print it
        array_len="$((RANDOM % 6))"
        echo -n " $array_len "
        next_char="${str:i+1:1}"
        complex_array=0
        # Check if the next character is a '(' (array of structures)
        if [ "$next_char" == '(' ]; then
          complex_array=1
          #i=$((i+1))
        fi
        sub_arr_len=0
         # Generate argument values for each element in the array recursively
        for ((j=0; j<array_len; j++)); do
          local inner_i="$i"
          # If it's a complex array, find the end of the array and recursively generate argument values for each element
          if [ "$complex_array" -eq 1 ]; then
            # Go till you find ')'
            while [ "$inner_i" -lt "$len" ]; do
              inner_i=$((inner_i+1))
              next_char="${str:$inner_i:1}"
              if [ "$next_char" = ')' ]; then
                break
              fi
              gen_arg "$str" "$inner_i" 1
              sub_arr_len=$((sub_arr_len+1))
            done
            inner_i=$((inner_i+1))
          else
            # If it's a simple array, recursively generate an argument value for the element
            # Go only for next char
            sub_arr_len=1
            gen_arg "$str" "$((inner_i+1))" 1  # Pass 1 to indicate we are inside an array
          fi
        done
        i=$((i+sub_arr_len))
        ;;
      ")")
      	# If it's the end of an array of structures, return to the previous level of recursion
        if [ "$in_array" -eq 2 ]; then
          return
        fi
        ;;
      "b")
        # boolean 
        echo -n " $((RANDOM % 2))"
        ;;
      "y")
	# If it's a byte, print a random hexadecimal value between 0x00 and 0xff
        printf " 0x%02x" $((RANDOM % 256)) 
        ;;
      "n")
        # int_16
        echo -n " $((RANDOM % 65536 - 32768))"
        ;;
      "q")
        # uint_16
        echo -n " $((RANDOM % 65536))"
        ;;
      "i")
        # int_32
        echo -n " $((RANDOM % 4294967296 - 2147483648))"
        ;;
      "u")
        # uint_32
        echo -n " $((RANDOM % 4294967296))"
        ;;
      "x")
       	# int_64
        echo -n " $((RANDOM % 18446744073709551616 - 9223372036854775808))"
        ;;
      "t")
        # uint_64
        echo -n " $((RANDOM % 18446744073709551616))"
        ;;
      "d")
        # double
        echo -n " $((RANDOM % 1000000000)).$((RANDOM % 1000000000))"
        ;;
      "s")
        # string
        echo -n " $(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom | head -c10)"
        ;;
      *)
        ;;
    esac
    
    if [ "$in_array" == "1" ]; then
      return
    fi
    
    i=$((i+1))
  done
}

fuzz_dbus_method() {
    username="$1"
    service_name="$2"
    object_path="$3"
    interface_name="$4"
    method_name="$5"
    arg_signature="$6"
    
    # escape () values
    escaped_signature=$(echo "$arg_signature" | sed 's/)/\\)/g')
    escaped_signature=$(echo "$escaped_signature" | sed 's/(/\\(/g')
    
    # Fuzz the method with random argument values
    echo "echo $method_name"
    echo "su - --shell=/bin/sh $username -c \"busctl call $service_name $object_path $interface_name $method_name $escaped_signature -- $(gen_arg $arg_signature 0 0)\""
}


# Check if the file name was provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 FILENAME"
    exit 1
fi

enumeration=()
# Declare an empty array to hold the input lines
input_lines=


# enumerate services, object paths, interfaces
while read -r line; do
  # Split line into three strings
  username=$(echo "$line" | cut -d ' ' -f 1)
  service_name=$(echo "$line" | cut -d ' ' -f 2)
  object_path=$(echo "$line" | cut -d ' ' -f 3)

    # Print out the username, service name and object path
    # echo "Processing username: $username, Service name: $service_name, Object path: $object_path"
       # Change the identity to the specified username and introspect the object path
    su - --shell=/bin/sh "$username" -c "busctl --no-pager --no-legend introspect $service_name $object_path" \
    | grep -w 'interface' \
    | awk '{if ($2 == "interface") print $1}' \
    | awk '{if ($1 !~ /^org\.freedesktop\.DBus/) print $0}' \
    | while read ifc; do
        #echo "Interface: $ifc"
        su - --shell=/bin/sh "$username" -c "busctl --no-pager --no-legend introspect $service_name $object_path $ifc" \
        	    | grep -w 'method' \
            | awk '{if ($2 == "method") print $0}' \
	    | while read meth; do \
		method=$(echo "$meth" | awk '{print $1}')
		signature=$(echo "$meth" | awk '{print $3}')

		echo "$username $service_name $object_path $ifc $method $signature"
		enumeration+="$username $service_name $object_path $ifc $method $signature"
		done
    done
done < "$1"

# create fuzz payload for each enumerated method
for i in "${enumeration[@]}"
do
  line="$i"
  username=$(echo "$line" | cut -d ' ' -f 1)
  service_name=$(echo "$line" | cut -d ' ' -f 2)
  object_path=$(echo "$line" | cut -d ' ' -f 3)
  interface=$(echo "$line" | cut -d ' ' -f 4)
  method_name=$(echo "$line" | cut -d ' ' -f 5)
  signature=$(echo "$line" | cut -d ' ' -f 6)
  
  if [[ $method_name == .* ]]; then
     method_name=${method_name#.}
  fi
  
  fuzz_dbus_method $username $service_name $object_path $interface $method_name $signature
done


