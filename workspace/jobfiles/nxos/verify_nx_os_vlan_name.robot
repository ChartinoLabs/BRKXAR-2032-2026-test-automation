*** Settings ***
Documentation       Description:
...                 * VLANs provide logical Layer 2 segmentation by partitioning a single physical switching infrastructure into multiple isolated broadcast domains.
...                 * On NX-OS, each VLAN is identified by a VLAN ID and can optionally be assigned a VLAN name to improve operational clarity, troubleshooting efficiency, and configuration readability.
...                 * Validating VLAN names is important because inconsistent or incorrect naming can lead to operational errors, misinterpretation during incident response, and increased risk of misconfiguration when changes are performed across multiple devices.
...                 * While VLAN naming does not typically change data plane forwarding behavior directly, accurate VLAN naming supports correct control plane and operational workflows by ensuring the intended VLAN-to-service mapping is clearly represented in device outputs and in automation systems that rely on consistent identifiers.
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
...                 {% for DUT_name in DUTS.keys() %}
...                 * {{ DUT_name }}
...                 {% endfor %}
...                 * On each device, run the command *show vlan brief* and capture the raw CLI output for reporting.
...                 * On each device, run the command *show vlan brief | json-pretty native* and parse the JSON output to extract the VLAN table entries.
...                 * From the parsed VLAN table, build a mapping of VLAN ID to the current VLAN name observed on the device.
...                 * For each device, iterate through each expected VLAN ID defined in the input parameters.
...                 * For each expected VLAN ID, verify the VLAN ID exists in the device VLAN table.
...                 * If the expected VLAN ID exists, compare the current VLAN name to the expected VLAN name for that VLAN ID.
...                 * Record a passing result when the VLAN exists and the current VLAN name matches the expected VLAN name.
...                 * Record a failing result when the VLAN does not exist or when the current VLAN name does not match the expected VLAN name.
...                 * Attach the full captured output of *show vlan brief* for each device to the final formatted results to support troubleshooting.
...
...                 Pass/Fail Criteria:
...                 * This test passes when all of the following conditions are met:
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
...                 * The VLAN name on each device matches the expected VLAN name for every expected VLAN ID.
...
...                 * This test fails if any of the following criteria are met:
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
...                 * Any expected VLAN ID is missing from the device VLAN table output.
...                 * Any expected VLAN ID exists but the VLAN name on the device does not match the expected VLAN name.
Test Tags           cait    status    nx-os    nxos    vlan    configuration    robot:continue-on-failure

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
${PASS_STR}    <p>All VLAN names on all devices match the expected values, so this test case has passed.</p>
${FAIL_STR}    <p>One or more VLAN names on one or more devices do not match the expected values, so this test case has failed.</p>


*** Test Cases ***
[NX-OS] Verify VLAN Name
    [Documentation]    Verify that the VLAN Name (vlanshowbr-vlanname) for each expected VLAN ID matches the expected value on one or more NX-OS devices.
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
                    ...    new_result=<p>The output of command <i>${current_DUT_data['command']}</i> from device ${DUT_name} indicates that VLAN ${expected_vlan_id} name is <b>${current_vlan_name}</b> as expected.</p>
                ELSE
                    Add Failing Result
                    ...    new_result=<p>The output of command <i>${current_DUT_data['command']}</i> from device ${DUT_name} indicates that VLAN ${expected_vlan_id} name is <b>${current_vlan_name}</b>, not <b>${expected_vlan_name}</b>, which is not expected.</p>
                END
            ELSE
                Add Failing Result
                ...    new_result=<p>The output of command <i>${current_DUT_data['command']}</i> from device ${DUT_name} indicates that VLAN ${expected_vlan_id} does not exist, which is not expected.</p>
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

        ${raw_command}=    Set Variable    show vlan brief
        ${raw_output}=    Run "${raw_command}"
        Log    ${raw_output}

        ${json_command}=    Set Variable    show vlan brief | json-pretty native
        ${parsed}=    Run Parsed Json ${json_command}
        Log    ${parsed}

        ${rows}=    Get From Dictionary    ${parsed}    TABLE_vlanbriefxbrief
        ${rows}=    Get From Dictionary    ${rows}    ROW_vlanbriefxbrief

        ${all_vlan_data}=    Create Dictionary
        FOR    ${row}    IN    @{rows}
            ${vlan_id}=    Get From Dictionary    ${row}    vlanshowbr-vlanid
            ${vlan_name}=    Get From Dictionary    ${row}    vlanshowbr-vlanname

            ${vlan_data}=    Create Dictionary
            ...    vlanshowbr-vlanname=${vlan_name}

            Set To Dictionary    ${all_vlan_data}    ${vlan_id}=${vlan_data}
        END

        ${gathered_dut_data}=    Create Dictionary    vlans=${all_vlan_data}

        IF    ${learning} == ${False}
            Set To Dictionary    ${gathered_dut_data}    command=${raw_command}    output=${raw_output}
        END

        Set To Dictionary    ${gathered_device_data}    ${DUT_name}=${gathered_dut_data}
    END

    RETURN    ${gathered_device_data}