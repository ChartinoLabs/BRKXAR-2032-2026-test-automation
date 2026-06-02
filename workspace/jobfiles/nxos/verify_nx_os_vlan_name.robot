*** Settings ***
Documentation       Description:
...                 * This test suite validates VLAN naming on one or more Cisco NX-OS devices by verifying that each expected VLAN ID is associated with the correct VLAN name.
...                 * A VLAN is a Layer 2 segmentation feature that logically separates broadcast domains on the same physical switching infrastructure, improving traffic isolation and organizational control.
...                 * VLAN names provide an administrative label for VLAN IDs, helping operations teams consistently identify intended segments across switches, reduce configuration ambiguity, and prevent miswiring or misassignment during changes.
...                 * Validating VLAN names is important for operational stability because incorrect or missing VLAN naming can lead to misinterpretation of network intent, slower troubleshooting, and increased risk of configuration drift across devices.
...                 * While VLAN naming does not directly change forwarding behavior in the data plane, it strongly influences day-to-day control and operational workflows by ensuring the VLAN-to-purpose mapping remains consistent across the environment and supporting accurate automation, monitoring, and audit processes.
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
...                 * Run the command *show vlan brief* on each device to capture the full CLI output for reporting purposes.
...                 * Run the command *show vlan brief | json-pretty native* on each device to retrieve VLAN brief information in structured JSON format.
...                 * Extract the VLAN table rows from the JSON output and build a mapping of VLAN ID to the current VLAN name learned from the device.
...                 * For each device, iterate through each expected VLAN ID defined in the input parameters.
...                 * For each expected VLAN ID, check whether the VLAN ID exists in the VLAN data learned from the device.
...                 * If the VLAN ID exists, retrieve the expected VLAN name and the current VLAN name and compare them as strings.
...                 * Record a passing result when the current VLAN name matches the expected VLAN name for that VLAN ID.
...                 * Record a failing result when the current VLAN name does not match the expected VLAN name for that VLAN ID.
...                 * Record a failing result when an expected VLAN ID is not present in the device VLAN table output.
...                 * Attach the full *show vlan brief* CLI output from each device to the final report for traceability.
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
...                 * For every expected VLAN ID, the VLAN name learned from the device matches the expected VLAN name.
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
...                 * At least one expected VLAN ID is missing from the device VLAN table output.
...                 * At least one expected VLAN ID exists but has a VLAN name that does not match the expected VLAN name.
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
${PASS_STR}    <p>All VLAN names gathered from the device(s) match the expected VLAN names, so this test case has passed.</p>
${FAIL_STR}    <p>One or more VLAN names gathered from the device(s) do not match the expected VLAN names, so this test case has failed.</p>


*** Test Cases ***
[NX-OS] Verify VLAN Name
    [Documentation]    Verify that each expected VLAN ID has the expected VLAN Name (vlanshowbr-vlanname) on one or more NX-OS devices.
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
                ${current_vlan_name}=    Get From Dictionary    ${current_vlan_data}    vlanshowbr-vlanname

                ${vlan_name_match}=    Run Keyword And Return Status
                ...    Should Be Equal As Strings
                ...    ${current_vlan_name}
                ...    ${expected_vlan_name}
                IF    ${vlan_name_match} == ${True}
                    Add Passing Result
                    ...    new_result=<p>The output of command <i>${current_DUT_data['command']}</i> from device ${DUT_name} indicates VLAN ${expected_vlan_id} name is <b>${current_vlan_name}</b>, as expected.</p>
                ELSE
                    Add Failing Result
                    ...    new_result=<p>The output of command <i>${current_DUT_data['command']}</i> from device ${DUT_name} indicates VLAN ${expected_vlan_id} name is <b>${current_vlan_name}</b>, not <b>${expected_vlan_name}</b>, which is not expected.</p>
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
    [Documentation]    Gather parameters from devices
    [Arguments]    ${learning}=${False}
    ${gathered_device_data}=    Create Dictionary

    FOR    ${DUT_name}    ${DUT_data}    IN    &{DUTS}
        Select Device "${DUT_name}"

        ${command}=    Set Variable    show vlan brief
        ${output}=    Run "${command}"
        Log    ${output}

        ${json_command}=    Set Variable    show vlan brief | json-pretty native
        ${parsed}=    Run Parsed Json ${json_command}
        Log    ${parsed}

        ${rows}=    Get From Dictionary    ${parsed}    TABLE_vlanbriefxbrief
        ${rows}=    Get From Dictionary    ${rows}    ROW_vlanbriefxbrief

        ${all_vlan_data}=    Create Dictionary
        FOR    ${row}    IN    @{rows}
            ${vlan_id}=    Get From Dictionary    ${row}    vlanshowbr-vlanid
            ${vlan_name}=    Get From Dictionary    ${row}    vlanshowbr-vlanname

            ${vlan_entry}=    Create Dictionary
            ...    vlanshowbr-vlanname=${vlan_name}

            Set To Dictionary    ${all_vlan_data}    ${vlan_id}=${vlan_entry}
        END

        ${gathered_dut_data}=    Create Dictionary    vlans=${all_vlan_data}

        IF    ${learning} == ${False}
            Set To Dictionary    ${gathered_dut_data}    command=${command}    output=${output}
        END

        Set To Dictionary    ${gathered_device_data}    ${DUT_name}=${gathered_dut_data}
    END

    RETURN    ${gathered_device_data}