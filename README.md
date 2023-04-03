# D-Bus Fuzzer
Bash tool for fuzz testing IPC communication written in Bash. 

- Enumerates D-Bus interfaces and its methods based on provided config file.
- Creates a fuzz payload containg randomized busctl calls based on methods signatures.
- Supports arrays and structures in method signatures, more complex containers may not be parsed .


## Usage

**./dbus_fuzzer.sh config_file.conf** > payload.sh

## Config file structure
Config file has one entry on each line.
Single entry has three elements separated by space: **username**, **service** and **object path**. 

`climate_user com.company.service.sender /com/company/sender/climate_api`
