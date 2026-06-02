*** Settings ***
Documentation       Description:
...                 * This test suite validates VLAN naming consistency on one or more Cisco NX-OS devices.
...                 * A VLAN is a Layer 2 segmentation feature that logically partitions a switch fabric into separate broadcast domains, allowing multiple isolated networks to share the same physical infrastructure.
...                 * VLAN names provide operational context for VLAN IDs by mapping numeric identifiers to human-meaningful labels used in day-to-day troubleshooting, change validation, and documentation alignment.
...                 * Validating VLAN names is important because incorrect or missing VLAN naming can lead to configuration drift, misinterpretation during incident response, and increased risk of provisioning errors that may impact application connectivity over the data plane.
...                 * While VLAN naming itself does not typically alter forwarding behavior, it directly affects operational workflows and reduces the likelihood of control plane and management plane mistakes when interpreting device state and implementing changes.
...
...                 Setup:
...                 * All devices are connected as per the main topology diagram.
...                 * All devices are powered up.
...                 {% if device_connectivity_type == 'console' %}
...                 * All devices are accessed through their console port via Reverse Telnet or Reverse SSH using a terminal or console server.
...                 {% elif device_connectivity_type == 'ssh' %}
...                 * All devices are accessed via SSH.
...                 {% elif device_connectivity_type == 'maglev' %}
...                 * All DNA Center (Catalyst Center) devices are accessed via SSH over the 'maglev' user.
...                 {% elif device_connectivity_type == 'cimc' %}
...                 * All devices are accessed through their CIMC connection.
...                 {% elif device_connectivity_type == 'rest' %}
...                 * All devices are accessed via REST API.
...                 {% endif %}
...
...                 Procedure:
...                 * Connect to the following devices:
...
...                 {% for DUT_name in DUTS.keys() %}
...                 * {{ DUT_name }}
...                 {% endfor %}
...
...                 * On each device, run the *show vlan brief* command to capture the raw CLI output for reporting purposes.
...                 * On each device, run the *show vlan brief | json-pretty native* command and parse the JSON output to extract the VLAN table entries.
...                 * For each device, iterate over each expected VLAN ID defined in the input parameters and search the parsed VLAN table for a matching VLAN ID.
...                 * If an expected VLAN ID is found, extract the current VLAN name from the parsed output and compare it to the expected VLAN name from the input parameters.
...                 * Record a passing result when the current VLAN name matches the expected VLAN name for the VLAN ID on that device.
...                 * Record a failing result when the current VLAN name does not match the expected VLAN name for the VLAN ID on that device.
...                 * Record a failing result when an expected VLAN ID is not present in the parsed VLAN table for that device.
...                 * Append the full *show vlan brief* output from each device into the formatted results to provide supporting evidence for any pass or fail conditions.
...
...                 Pass/Fail Criteria:
...                 * This test passes when all of the following conditions are met:
...
...                 {% if device_connectivity_type == 'console' %}
...                 * The Reverse Telnet or Reverse SSH connection through the terminal or console server is successful.
...                 {% elif device_connectivity_type == 'ssh' %}
...                 * SSH connectivity to each device is successful.
...                 {% elif device_connectivity_type == 'rest' %}
...                 * REST API connectivity to each device is established successfully.
...                 * Authentication over REST API is successful.
...                 {% elif device_connectivity_type == 'cimc' %}
...                 * Connectivity through the CIMC of each device is established successfully.
...                 {% elif device_connectivity_type == 'maglev' %}
...                 * SSH connectivity over the 'maglev' user to each DNA Center (Catalyst Center) device is successful.
...                 {% endif %}
...                 * Every expected VLAN ID exists on each device where it is defined in the input parameters.
...                 * For every expected VLAN ID, the VLAN name reported by *show vlan brief | json-pretty native* matches the expected VLAN name.
...
...                 * This test fails if any of the following criteria are met:
...
...                 {% if device_connectivity_type == 'console' %}
...                 * The terminal or console server is unreachable over the network.
...                 * The console port of the device is unresponsive
...                 * The incorrect device (as determined by the device's hostname) is accessible through the terminal or console server.
...                 * Authentication against the device's console line is unsuccessful.
...                 {% elif device_connectivity_type == 'ssh' %}
...                 * The device is unreachable over the network.
...                 * The device is not responsive to SSH connections.
...                 * The incorrect device (as determined by the device's hostname) is accessible via SSH.
...                 * Authentication against the device is unsuccessful.
...                 {% elif device_connectivity_type == 'rest' %}
...                 * REST API connectivity to each device cannot be established.
...                 * Authentication over REST API is unsuccessful.
...                 {% elif device_connectivity_type == 'cimc' %}
...                 * The device's CIMC connection is unreachable over the network.
...                 * The CIMC of the device is unresponsive.
...                 * The incorrect device (as determined by the device's hostname) is accessible through
...                 the CIMC connection.
...                 * Authentication against the device's CIMC is unsuccessful.
...                 {% elif device_connectivity_type == 'maglev' %}
...                 * The DNA Center (Catalyst Center) appliance is unreachable over the network.
...                 * The DNA Center (Catalyst Center) appliance is not responsive to SSH connections.
...                 * The incorrect DNAC appliance (as determined by the appliance's hostname) is accessible via SSH.
...                 * Authentication against the DNAC appliance is unsuccessful.
...                 {% endif %}
...                 * Any expected VLAN ID is missing from the device output.
...                 * Any VLAN name does not match the expected VLAN name for the corresponding VLAN ID.
Test Tags           cait    status    nx-os    nxos    vlan    robot:continue-on-failure

# Include all the keywords from the opensource libraries from robot framework:
# http://robotframework.org/robotframework/#standard-libraries
Library             String
Library             BuiltIn
Library             DateTime
Library             Collections
Library             OperatingSystem

# Cisco (SVS CXTA) Libraries
Library             CXTA
Resource            cxta.robot

# Update/uncomment the line below with the file used or delete if not applicable
Resource            ${EXECDIR}/workspace/resources/keywords.resource

Suite Setup         Run Keywords
...                     Load Testbed "${EXECDIR}/workspace/testbed.yaml"
...                     AND    Validate Connection To Devices    ${DUTS}    ${device_connectivity_type}

Suite Teardown      Run Keywords
...                     Disconnect From All Devices
...                     AND    Generate Final Formatted Result    ${PASS_STR}    ${FAIL_STR}


*** Variables ***
${PASS_STR}    <p>All VLAN names (vlanshowbr-vlanname) on all devices match the expected values for the specified VLAN IDs, so this test case has passed.</p>
${FAIL_STR}    <p>One or more VLAN names (vlanshowbr-vlanname) on one or more devices do not match the expected values for the specified VLAN IDs, so this test case has failed.</p>


*** Test Cases ***
[NX-OS] Verify VLAN Name
    [Documentation]    Verify VLAN Name for specified VLAN IDs on one or more NX-OS devices using the Genie/NXOS JSON output of "show vlan brief | json-pretty native".
    ${current_device_data}=    Gather Parameters
    Log    ${current_device_data}

    FOR    ${DUT_name}    ${DUT_data}    IN    &{DUTS}
        ${current_DUT_data}=    Get From Dictionary    ${current_device_data}    ${DUT_name}

        FOR    ${expected_vlan_id}    ${expected_vlan_data}    IN    &{DUT_data['vlans']}
            ${vlan_currently_exists}    ${current_vlan_data}=    Run Keyword And Ignore Error
            ...    Get From Dictionary
            ...    ${current_DUT_data['vlans']}
            ...    ${expected_vlan_id}

            IF    "${vlan_currently_exists}" == "PASS"
                ${expected_vlan_name}=    Get From Dictionary    ${expected_vlan_data}    vlanshowbr-vlanname
                ${current_vlan_name}=     Get From Dictionary    ${current_vlan_data}     vlanshowbr-vlanname

                ${vlan_name_match}=    Run Keyword And Return Status
                ...    Should Be Equal As Strings
                ...    ${current_vlan_name}
                ...    ${expected_vlan_name}

                IF    ${vlan_name_match} == ${True}
                    Add Passing Result
                    ...    new_result=<p>The output of command <i>${current_DUT_data['command']}</i> from device ${DUT_name} indicates VLAN ${expected_vlan_id} has name <b>${current_vlan_name}</b>, which matches the expected value.</p>
                ELSE
                    Add Failing Result
                    ...    new_result=<p>The output of command <i>${current_DUT_data['command']}</i> from device ${DUT_name} indicates VLAN ${expected_vlan_id} has name <b>${current_vlan_name}</b>, not <b>${expected_vlan_name}</b>, which is not expected.</p>
                END
            ELSE
                Add Failing Result
                ...    new_result=<p>The output of command <i>${current_DUT_data['command']}</i> from device ${DUT_name} indicates VLAN ${expected_vlan_id} does not exist, which is not expected.</p>
            END
        END

        Add Formatted Text To Result
        ...    new_result=<p>The full output of command <i>${current_DUT_data['command']}</i> from device ${DUT_name} is shown below.</p>
        ...    device_name=${DUT_name}
        ...    command=${current_DUT_data['command']}
        ...    command_output=${current_DUT_data['output']}
    END

Learn Parameters
    [Documentation]    Learn parameters for Robot scripts.
    [Tags]    learner
    ${parameters}=    Create Dictionary    device_connectivity_type=${device_connectivity_type}
    ${dut_parameters}=    Gather Parameters    learning=${True}
    Set To Dictionary    ${parameters}    DUTS=${dut_parameters}
    ${parameters_as_string}=    Convert JSON To String    ${parameters}
    Create File    path=${OUTPUTDIR}/parameters.json    content=${parameters_as_string}


*** Keywords ***
Gather Parameters
    [Documentation]    Gather VLAN name parameters from devices using NX-OS JSON output for "show vlan brief | json-pretty native".
    [Arguments]    ${learning}=${False}
    ${gathered_device_data}=    Create Dictionary

    FOR    ${DUT_name}    ${DUT_data}    IN    &{DUTS}
        Select Device "${DUT_name}"

        ${gather_vlan_command}=    Set Variable    show vlan brief
        ${gather_vlan_output}=     Run "${gather_vlan_command}"
        Log    ${gather_vlan_output}

        ${gather_vlan_json_command}=    Set Variable    show vlan brief | json-pretty native
        ${parsed_vlan_json}=            Run Parsed Json ${gather_vlan_json_command}
        Log    ${parsed_vlan_json}

        ${rows}=    Get From Dictionary    ${parsed_vlan_json}    TABLE_vlanbriefxbrief
        ${rows}=    Get From Dictionary    ${rows}               ROW_vlanbriefxbrief

        ${all_vlan_data}=    Create Dictionary
        FOR    ${expected_vlan_id}    ${expected_vlan_data}    IN    &{DUT_data['vlans']}
            ${found_vlan_name}=    Set Variable    ${None}

            FOR    ${row}    IN    @{rows}
                ${row_vlan_id}=    Get From Dictionary    ${row}    vlanshowbr-vlanid
                ${id_match}=    Run Keyword And Return Status
                ...    Should Be Equal As Integers
                ...    ${row_vlan_id}
                ...    ${expected_vlan_id}
                IF    ${id_match} == ${True}
                    ${found_vlan_name}=    Get From Dictionary    ${row}    vlanshowbr-vlanname
                    Exit For Loop
                END
            END

            IF    '${found_vlan_name}' != '${None}'
                ${vlan_schema_data}=    Create Dictionary    vlanshowbr-vlanname=${found_vlan_name}
                Set To Dictionary    ${all_vlan_data}    ${expected_vlan_id}=${vlan_schema_data}
            END
        END

        ${gathered_dut_data}=    Create Dictionary    vlans=${all_vlan_data}

        IF    ${learning} == ${False}
            Set To Dictionary    ${gathered_dut_data}    command=${gather_vlan_command}    output=${gather_vlan_output}
        END

        Set To Dictionary    ${gathered_device_data}    ${DUT_name}=${gathered_dut_data}
    END

    RETURN    ${gathered_device_data}