*** Settings ***
Documentation       Description:
...                 * Open Shortest Path First (OSPF) is a link-state interior gateway protocol used to exchange routing information within an autonomous system.
...                 * OSPF builds a link-state database and runs the SPF algorithm to compute best paths, making it a foundational control-plane component for dynamic routing and fast convergence.
...                 * The OSPF router ID uniquely identifies an OSPF router within an OSPF domain and is used in neighbor relationships, LSA origination, and SPF calculations.
...                 * Validating the OSPF router ID per VRF and per OSPF instance is important because an unexpected router ID can prevent adjacencies from forming, cause LSA and topology inconsistencies, and lead to unstable routing behavior that impacts application reachability and overall network stability.
...                 * This test verifies that the learned OSPF router ID values from the device control plane match the expected values provided in the jobfile parameters for each VRF and OSPF instance.
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
...                 * Run the *show vrf* command on each device to learn the set of VRFs present on the device.
...                 * Parse the *show vrf* output to build a per-device list of VRF names to be validated and to be used for follow-up OSPF queries.
...                 * For each discovered VRF on each device, run the *show ip ospf vrf {vrf_name}* command to collect OSPF operational data for that VRF.
...                 * Parse the *show ip ospf vrf {vrf_name}* output to extract the IPv4 OSPF instance blocks and the router ID value for each instance.
...                 * For each device defined in the jobfile parameters, iterate through each expected VRF and confirm that the VRF exists in the learned device data.
...                 * For each expected VRF, iterate through each expected IPv4 OSPF instance ID and confirm that the instance exists in the learned device data.
...                 * For each expected OSPF instance, compare the learned router ID value at *vrf.{vrf_name}.address_family.ipv4.instance.{instance_id}.router_id* to the expected router ID value from the jobfile parameters.
...                 * Record a pass result when the expected router ID matches the learned router ID for the specific device, VRF, and instance.
...                 * Record a fail result when any expected VRF is missing, any expected OSPF instance is missing, or any router ID does not match the expected value.
...                 * Attach the full captured output of *show vrf* for each device to the formatted results for troubleshooting and auditability.
...                 * Attach the full captured output of each *show ip ospf vrf {vrf_name}* command for each device to the formatted results when available.
...                 * Record a fail result if the OSPF command string for a VRF was not captured or if no command output was captured for *show ip ospf vrf {vrf_name}*.
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
...                 * Every expected VRF defined in the jobfile parameters exists on the corresponding device.
...                 * Every expected IPv4 OSPF instance defined under each expected VRF exists on the corresponding device.
...                 * For every expected device, VRF, and OSPF instance, the learned OSPF router ID exactly matches the expected router ID value from the jobfile parameters.
...                 * The command output for *show vrf* and *show ip ospf vrf {vrf_name}* is captured successfully for inclusion in the results.
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
...                 * At least one expected VRF defined in the jobfile parameters does not exist on the device.
...                 * At least one expected IPv4 OSPF instance defined in the jobfile parameters does not exist under the expected VRF on the device.
...                 * At least one learned OSPF router ID does not match the expected router ID for the corresponding device, VRF, and OSPF instance.
...                 * The command string for *show ip ospf vrf {vrf_name}* is missing for any VRF where it is expected to be available in the collected data.
...                 * No output is captured for any executed *show ip ospf vrf {vrf_name}* command.
Test Tags           cait    status    routing    ospf    nx-os    nxos    robot:continue-on-failure

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
${PASS_STR}    <p>All OSPF router IDs on the device match the expected values, so this test case has passed.</p>
${FAIL_STR}    <p>One or more OSPF router IDs on the device do not match the expected values, so this test case has failed.</p>


*** Test Cases ***
[NX-OS] Verify OSPF Router ID
    [Documentation]    Verify the OSPF router ID for each OSPF instance in each VRF on NX-OS devices.
    ${current_device_data}=    Gather Parameters
    Log    ${current_device_data}

    FOR    ${DUT_name}    ${DUT_data}    IN    &{DUTS}
        ${current_DUT_data}=    Get From Dictionary    ${current_device_data}    ${DUT_name}

        FOR    ${expected_vrf_name}    ${expected_vrf_data}    IN    &{DUT_data['vrf']}
            ${vrf_exists}    ${current_vrf_data}=    Run Keyword And Ignore Error
            ...    Get From Dictionary
            ...    ${current_DUT_data['vrf']}
            ...    ${expected_vrf_name}

            IF    "${vrf_exists}" == "PASS"
                FOR    ${expected_instance_id}    ${expected_instance_data}    IN    &{expected_vrf_data['address_family']['ipv4']['instance']}
                    ${instance_exists}    ${current_instance_data}=    Run Keyword And Ignore Error
                    ...    Get From Dictionary
                    ...    ${current_vrf_data['address_family']['ipv4']['instance']}
                    ...    ${expected_instance_id}

                    IF    "${instance_exists}" == "PASS"
                        ${expected_router_id}=    Get From Dictionary    ${expected_instance_data}    router_id
                        ${current_router_id}=    Get From Dictionary    ${current_instance_data}    router_id

                        IF    "${expected_router_id}" == "${current_router_id}"
                            Add Passing Result
                            ...    new_result=<p>On device ${DUT_name}, VRF ${expected_vrf_name} OSPF instance ${expected_instance_id} router ID is ${current_router_id} as expected.</p>
                        ELSE
                            Add Failing Result
                            ...    new_result=<p>On device ${DUT_name}, VRF ${expected_vrf_name} OSPF instance ${expected_instance_id} router ID is ${current_router_id}, not ${expected_router_id}, which is not expected.</p>
                        END
                    ELSE
                        Add Failing Result
                        ...    new_result=<p>On device ${DUT_name}, VRF ${expected_vrf_name} OSPF instance ${expected_instance_id} does not exist, which is not expected.</p>
                    END
                END
            ELSE
                Add Failing Result
                ...    new_result=<p>On device ${DUT_name}, VRF ${expected_vrf_name} does not exist, which is not expected.</p>
            END
        END

        Add Formatted Text To Result
        ...    new_result=<p>The full output of command <i>${current_DUT_data['show_vrf_command']}</i> from device ${DUT_name} is shown below.</p>
        ...    device_name=${DUT_name}
        ...    command=${current_DUT_data['show_vrf_command']}
        ...    command_output=${current_DUT_data['show_vrf_output']}

        FOR    ${vrf_name}    ${vrf_data}    IN    &{current_DUT_data['vrf']}
            ${ospf_command_exists}    ${ospf_command}=    Run Keyword And Ignore Error
            ...    Get From Dictionary
            ...    ${vrf_data}
            ...    ospf_command
            ${ospf_output_exists}    ${ospf_output}=    Run Keyword And Ignore Error
            ...    Get From Dictionary
            ...    ${vrf_data}
            ...    ospf_output

            IF    "${ospf_command_exists}" == "PASS"
                IF    "${ospf_output_exists}" == "PASS"
                    Add Formatted Text To Result
                    ...    new_result=<p>The full output of command <i>${ospf_command}</i> from device ${DUT_name} is shown below.</p>
                    ...    device_name=${DUT_name}
                    ...    command=${ospf_command}
                    ...    command_output=${ospf_output}
                ELSE
                    Add Failing Result
                    ...    new_result=<p>On device ${DUT_name}, no output was captured for command <i>${ospf_command}</i>, which is not expected.</p>
                END
            ELSE
                Add Failing Result
                ...    new_result=<p>On device ${DUT_name}, the OSPF VRF command string was not captured for VRF ${vrf_name}, which is not expected.</p>
            END
        END
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
    [Documentation]    Gather OSPF router-id parameters per VRF and instance from devices using Genie parsers.
    [Tags]    robot:continue-on-failure
    [Arguments]    ${learning}=${False}
    ${gathered_device_data}=    Create Dictionary

    FOR    ${DUT_name}    ${DUT_data}    IN    &{DUTS}
        Select Device "${DUT_name}"

        ${show_vrf_command}=    Set Variable    show vrf
        ${show_vrf_output}=    Run "${show_vrf_command}"
        Log    ${show_vrf_output}
        ${show_vrf_parsed}=    Parse Output "${show_vrf_output}" Using Parser "${show_vrf_command}" On Device "${DUT_name}"
        Log    ${show_vrf_parsed}

        ${vrf_dict}=    Create Dictionary
        FOR    ${vrf_name}    ${vrf_data}    IN    &{show_vrf_parsed['vrfs']}
            ${ospf_command}=    Set Variable    show ip ospf vrf ${vrf_name}
            ${ospf_output}=    Run "${ospf_command}"
            Log    ${ospf_output}
            ${ospf_parsed}=    Parse Output "${ospf_output}" Using Parser "${ospf_command}" On Device "${DUT_name}"
            Log    ${ospf_parsed}

            ${instances}=    Create Dictionary
            ${vrf_exists}    ${vrf_parsed_block}=    Run Keyword And Ignore Error
            ...    Get From Dictionary
            ...    ${ospf_parsed['vrf']}
            ...    ${vrf_name}

            IF    "${vrf_exists}" == "PASS"
                ${af_exists}    ${af_block}=    Run Keyword And Ignore Error
                ...    Get From Dictionary
                ...    ${vrf_parsed_block['address_family']}
                ...    ipv4

                IF    "${af_exists}" == "PASS"
                    ${inst_exists}    ${inst_block}=    Run Keyword And Ignore Error
                    ...    Get From Dictionary
                    ...    ${af_block}
                    ...    instance

                    IF    "${inst_exists}" == "PASS"
                        FOR    ${instance_id}    ${instance_data}    IN    &{inst_block}
                            ${router_id_exists}    ${router_id}=    Run Keyword And Ignore Error
                            ...    Get From Dictionary
                            ...    ${instance_data}
                            ...    router_id
                            IF    "${router_id_exists}" == "PASS"
                                ${instance_subset}=    Create Dictionary    router_id=${router_id}
                                Set To Dictionary    ${instances}    ${instance_id}=${instance_subset}
                            ELSE
                                ${instance_subset}=    Create Dictionary    router_id=
                                Set To Dictionary    ${instances}    ${instance_id}=${instance_subset}
                            END
                        END
                    END
                END
            END

            ${vrf_subset}=    Create Dictionary
            ...    address_family=${{'ipv4': {'instance': ${instances}}}}

            IF    ${learning} == ${False}
                Set To Dictionary    ${vrf_subset}    ospf_command=${ospf_command}    ospf_output=${ospf_output}
            END

            Set To Dictionary    ${vrf_dict}    ${vrf_name}=${vrf_subset}
        END

        ${current_DUT_data}=    Create Dictionary    vrf=${vrf_dict}

        IF    ${learning} == ${False}
            Set To Dictionary
            ...    ${current_DUT_data}
            ...    show_vrf_command=${show_vrf_command}
            ...    show_vrf_output=${show_vrf_output}
        END

        Set To Dictionary    ${gathered_device_data}    ${DUT_name}=${current_DUT_data}
    END

    RETURN    ${gathered_device_data}