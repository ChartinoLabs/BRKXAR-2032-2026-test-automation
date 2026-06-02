*** Settings ***
Documentation       Description:
...                 * This test suite validates Enhanced Interior Gateway Routing Protocol (EIGRP) neighbor adjacencies on Cisco IOS-XE devices.
...                 * EIGRP is a dynamic routing protocol that forms neighbor relationships to exchange routing information and maintain loop-free paths through the network.
...                 * Verifying EIGRP neighbor adjacencies is critical because missing or unexpected neighbors can prevent route exchange, cause traffic blackholing, increase convergence time, and negatively impact application reachability.
...                 * EIGRP neighbor formation and maintenance is a control-plane function that directly influences the routing table and forwarding decisions in the data plane; unstable adjacencies can also increase control-plane churn and device CPU utilization.
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
...                 Connect to the following devices:
...
...                 {% for DUT_name in DUTS.keys() %}
...                 * {{ DUT_name }}
...                 {% endfor %}
...
...                 * Run the *show vrf* command on each device and parse the output to determine the set of VRFs to evaluate.
...                 * For each VRF discovered on each device, run the *show ip eigrp vrf {vrf} neighbors* command and parse the output to learn the current EIGRP neighbor adjacencies.
...                 * Build a normalized, schema-aligned view of the current EIGRP state per device using the hierarchy *eigrp_instance* to *vrf* to *address_family* to *eigrp_interface* to *eigrp_nbr*, recording only the neighbor IP keys for validation.
...                 * For each device, read the expected neighbor IPs from job parameters using the same hierarchy *eigrp_instance* to *vrf* to *address_family* to *eigrp_interface* to *eigrp_nbr*.
...                 * For each expected EIGRP instance, confirm the instance exists in the parsed device state; record a failure if the instance is missing.
...                 * For each expected VRF under each expected instance, confirm the VRF exists in the parsed device state; record a failure if the VRF is missing.
...                 * For each expected address-family under each expected VRF, confirm the address-family exists in the parsed device state; record a failure if the address-family is missing.
...                 * For each expected EIGRP interface under each expected address-family, confirm the interface exists in the parsed device state; record a failure if the interface is missing.
...                 * For each expected neighbor IP under each expected interface, confirm the neighbor IP exists in the parsed device state; record a pass if present and a failure if not present.
...                 * Capture and include in the results the full CLI output of *show vrf* for each device.
...                 * Capture and include in the results the full CLI output of each executed *show ip eigrp vrf {vrf} neighbors* command for each device.
...
...                 Pass/Fail Criteria:
...                 This test passes when all of the following conditions are met:
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
...                 * Expected EIGRP instances are provided for each device and are present in the parsed device state.
...                 * Expected VRFs are provided for each expected EIGRP instance and are present in the parsed device state.
...                 * Expected address-families are provided for each expected VRF and are present in the parsed device state.
...                 * Expected EIGRP interfaces are provided for each expected address-family and are present in the parsed device state.
...                 * Every expected EIGRP neighbor IP is present in the parsed device state under the expected instance, VRF, address-family, and interface.
...                 * The *show vrf* output and the *show ip eigrp vrf {vrf} neighbors* outputs are successfully captured for inclusion in the results.
...
...                 This test fails if any of the following criteria are met:
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
...                 * No expected EIGRP instances are provided for a device, preventing adjacency validation.
...                 * An expected EIGRP instance, VRF, address-family, or EIGRP interface is missing from the parsed device state.
...                 * No expected neighbors are provided under an expected EIGRP interface, preventing adjacency validation.
...                 * Any expected EIGRP neighbor IP is not present in the parsed device state under the expected instance, VRF, address-family, and interface.
...                 * EIGRP neighbor command outputs are not captured for a device, preventing inclusion of required CLI evidence in the results.
Test Tags           cait    ios-xe    iosxe    eigrp    routing    neighbor    adjacency    status    robot:continue-on-failure

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
${PASS_STR}    <p>All expected EIGRP neighbor adjacencies match the device state, so this test case has passed.</p>
${FAIL_STR}    <p>One or more expected EIGRP neighbor adjacencies do not match the device state, so this test case has failed.</p>


*** Test Cases ***
[IOS-XE] Verify EIGRP Neighbor Adjacencies
    [Documentation]    Verify EIGRP neighbor adjacencies per EIGRP instance/VRF/address-family/interface/neighbor IP.
    ${current_device_data}=    Gather Parameters
    Log    ${current_device_data}

    FOR    ${DUT_name}    ${DUT_data}    IN    &{DUTS}
        ${current_DUT_data}=    Get From Dictionary    ${current_device_data}    ${DUT_name}

        ${expected_instances_exist}    ${expected_instances}=    Run Keyword And Ignore Error
        ...    Get From Dictionary
        ...    ${DUT_data}
        ...    eigrp_instance
        IF    "${expected_instances_exist}" == "PASS"
            FOR    ${expected_instance}    ${expected_instance_data}    IN    &{expected_instances}
                ${current_instance_exists}    ${current_instance_data}=    Run Keyword And Ignore Error
                ...    Get From Dictionary
                ...    ${current_DUT_data['eigrp_instance']}
                ...    ${expected_instance}
                IF    "${current_instance_exists}" == "PASS"
                    ${expected_vrfs_exist}    ${expected_vrfs}=    Run Keyword And Ignore Error
                    ...    Get From Dictionary
                    ...    ${expected_instance_data}
                    ...    vrf
                    IF    "${expected_vrfs_exist}" == "PASS"
                        FOR    ${expected_vrf_name}    ${expected_vrf_data}    IN    &{expected_vrfs}
                            ${current_vrf_exists}    ${current_vrf_data}=    Run Keyword And Ignore Error
                            ...    Get From Dictionary
                            ...    ${current_instance_data['vrf']}
                            ...    ${expected_vrf_name}
                            IF    "${current_vrf_exists}" == "PASS"
                                ${expected_afs_exist}    ${expected_afs}=    Run Keyword And Ignore Error
                                ...    Get From Dictionary
                                ...    ${expected_vrf_data}
                                ...    address_family
                                IF    "${expected_afs_exist}" == "PASS"
                                    FOR    ${expected_af}    ${expected_af_data}    IN    &{expected_afs}
                                        ${current_af_exists}    ${current_af_data}=    Run Keyword And Ignore Error
                                        ...    Get From Dictionary
                                        ...    ${current_vrf_data['address_family']}
                                        ...    ${expected_af}
                                        IF    "${current_af_exists}" == "PASS"
                                            ${expected_intfs_exist}    ${expected_intfs}=    Run Keyword And Ignore Error
                                            ...    Get From Dictionary
                                            ...    ${expected_af_data}
                                            ...    eigrp_interface
                                            IF    "${expected_intfs_exist}" == "PASS"
                                                FOR    ${expected_intf}    ${expected_intf_data}    IN    &{expected_intfs}
                                                    ${current_intf_exists}    ${current_intf_data}=    Run Keyword And Ignore Error
                                                    ...    Get From Dictionary
                                                    ...    ${current_af_data['eigrp_interface']}
                                                    ...    ${expected_intf}
                                                    IF    "${current_intf_exists}" == "PASS"
                                                        ${expected_nbrs_exist}    ${expected_nbrs}=    Run Keyword And Ignore Error
                                                        ...    Get From Dictionary
                                                        ...    ${expected_intf_data}
                                                        ...    eigrp_nbr
                                                        IF    "${expected_nbrs_exist}" == "PASS"
                                                            FOR    ${expected_nbr_ip}    ${expected_nbr_data}    IN    &{expected_nbrs}
                                                                ${current_nbr_exists}    ${current_nbr_data}=    Run Keyword And Ignore Error
                                                                ...    Get From Dictionary
                                                                ...    ${current_intf_data['eigrp_nbr']}
                                                                ...    ${expected_nbr_ip}
                                                                IF    "${current_nbr_exists}" == "PASS"
                                                                    Add Passing Result
                                                                    ...    new_result=<p>EIGRP neighbor ${expected_nbr_ip} is present on device ${DUT_name} (instance ${expected_instance}, VRF ${expected_vrf_name}, AF ${expected_af}, interface ${expected_intf}) as expected.</p>
                                                                ELSE
                                                                    Add Failing Result
                                                                    ...    new_result=<p>EIGRP neighbor ${expected_nbr_ip} is NOT present on device ${DUT_name} (instance ${expected_instance}, VRF ${expected_vrf_name}, AF ${expected_af}, interface ${expected_intf}), which is not expected.</p>
                                                                END
                                                            END
                                                        ELSE
                                                            Add Failing Result
                                                            ...    new_result=<p>No expected neighbors were provided for device ${DUT_name} (instance ${expected_instance}, VRF ${expected_vrf_name}, AF ${expected_af}, interface ${expected_intf}); unable to validate adjacencies.</p>
                                                        END
                                                    ELSE
                                                        Add Failing Result
                                                        ...    new_result=<p>EIGRP interface ${expected_intf} is NOT present on device ${DUT_name} (instance ${expected_instance}, VRF ${expected_vrf_name}, AF ${expected_af}), which is not expected.</p>
                                                    END
                                                END
                                            ELSE
                                                Add Failing Result
                                                ...    new_result=<p>No expected EIGRP interfaces were provided for device ${DUT_name} (instance ${expected_instance}, VRF ${expected_vrf_name}, AF ${expected_af}); unable to validate adjacencies.</p>
                                            END
                                        ELSE
                                            Add Failing Result
                                            ...    new_result=<p>Address-family ${expected_af} is NOT present on device ${DUT_name} (instance ${expected_instance}, VRF ${expected_vrf_name}), which is not expected.</p>
                                        END
                                    END
                                ELSE
                                    Add Failing Result
                                    ...    new_result=<p>No expected address-families were provided for device ${DUT_name} (instance ${expected_instance}, VRF ${expected_vrf_name}); unable to validate adjacencies.</p>
                                END
                            ELSE
                                Add Failing Result
                                ...    new_result=<p>VRF ${expected_vrf_name} is NOT present in EIGRP instance ${expected_instance} on device ${DUT_name}, which is not expected.</p>
                            END
                        END
                    ELSE
                        Add Failing Result
                        ...    new_result=<p>No expected VRFs were provided for device ${DUT_name} (instance ${expected_instance}); unable to validate adjacencies.</p>
                    END
                ELSE
                    Add Failing Result
                    ...    new_result=<p>EIGRP instance ${expected_instance} is NOT present on device ${DUT_name}, which is not expected.</p>
                END
            END
        ELSE
            Add Failing Result
            ...    new_result=<p>No expected EIGRP instances were provided for device ${DUT_name}; unable to validate adjacencies.</p>
        END

        Add Formatted Text To Result
        ...    new_result=<p>The full output of command <i>${current_DUT_data['vrf_command']}</i> from device ${DUT_name} is shown below.</p>
        ...    device_name=${DUT_name}
        ...    command=${current_DUT_data['vrf_command']}
        ...    command_output=${current_DUT_data['vrf_output']}

        ${eigrp_outputs_exist}    ${eigrp_outputs}=    Run Keyword And Ignore Error
        ...    Get From Dictionary
        ...    ${current_DUT_data}
        ...    eigrp_neighbor_outputs
        IF    "${eigrp_outputs_exist}" == "PASS"
            FOR    ${eigrp_command}    ${eigrp_output}    IN    &{eigrp_outputs}
                Add Formatted Text To Result
                ...    new_result=<p>The full output of command <i>${eigrp_command}</i> from device ${DUT_name} is shown below.</p>
                ...    device_name=${DUT_name}
                ...    command=${eigrp_command}
                ...    command_output=${eigrp_output}
            END
        ELSE
            Add Failing Result
            ...    new_result=<p>No EIGRP neighbor command outputs were captured for device ${DUT_name}; unable to include CLI outputs in results.</p>
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
    [Documentation]    Gather EIGRP neighbor adjacency parameters from devices using Genie parsers.
    [Tags]    robot:continue-on-failure
    [Arguments]    ${learning}=${False}
    ${gathered_device_data}=    Create Dictionary

    FOR    ${DUT_name}    ${DUT_data}    IN    &{DUTS}
        Select Device "${DUT_name}"
        ${current_DUT_data}=    Create Dictionary

        # show vrf (Genie)
        ${vrf_command}=    Set Variable    show vrf
        ${vrf_output}=    Run "${vrf_command}"
        Log    ${vrf_output}
        ${vrf_parsed}=    Parse Output "${vrf_output}" Using Parser "${vrf_command}" On Device "${DUT_data['name']}"
        Log    ${vrf_parsed}

        # Build schema-aligned structure: eigrp_instance -> vrf -> address_family -> eigrp_interface -> eigrp_nbr
        ${eigrp_instances}=    Create Dictionary
        ${eigrp_neighbor_outputs}=    Create Dictionary

        ${vrfs_exist}    ${vrfs}=    Run Keyword And Ignore Error
        ...    Get From Dictionary
        ...    ${vrf_parsed}
        ...    vrf
        IF    "${vrfs_exist}" == "PASS"
            FOR    ${vrf_name}    ${vrf_data}    IN    &{vrfs}
                # show ip eigrp vrf <VRF> neighbors (Genie)
                ${eigrp_command}=    Set Variable    show ip eigrp vrf ${vrf_name} neighbors
                ${eigrp_output}=    Run "${eigrp_command}"
                Log    ${eigrp_output}
                ${eigrp_parsed}=    Parse Output "${eigrp_output}" Using Parser "${eigrp_command}" On Device "${DUT_data['name']}"
                Log    ${eigrp_parsed}

                IF    ${learning} == ${False}
                    Set To Dictionary    ${eigrp_neighbor_outputs}    ${eigrp_command}=${eigrp_output}
                END

                ${parsed_instances_exist}    ${parsed_instances}=    Run Keyword And Ignore Error
                ...    Get From Dictionary
                ...    ${eigrp_parsed}
                ...    eigrp_instance
                IF    "${parsed_instances_exist}" == "PASS"
                    FOR    ${instance}    ${instance_data}    IN    &{parsed_instances}
                        ${instance_dict_exists}    ${instance_dict}=    Run Keyword And Ignore Error
                        ...    Get From Dictionary
                        ...    ${eigrp_instances}
                        ...    ${instance}
                        IF    "${instance_dict_exists}" == "PASS"
                            ${instance_entry}=    Set Variable    ${instance_dict}
                        ELSE
                            ${instance_entry}=    Create Dictionary    vrf=${EMPTY}
                            ${instance_vrfs}=    Create Dictionary
                            Set To Dictionary    ${instance_entry}    vrf=${instance_vrfs}
                            Set To Dictionary    ${eigrp_instances}    ${instance}=${instance_entry}
                        END

                        ${parsed_vrfs_exist}    ${parsed_vrfs}=    Run Keyword And Ignore Error
                        ...    Get From Dictionary
                        ...    ${instance_data}
                        ...    vrf
                        IF    "${parsed_vrfs_exist}" == "PASS"
                            ${parsed_vrf_exists}    ${parsed_vrf_data}=    Run Keyword And Ignore Error
                            ...    Get From Dictionary
                            ...    ${parsed_vrfs}
                            ...    ${vrf_name}
                            IF    "${parsed_vrf_exists}" == "PASS"
                                ${instance_vrfs}=    Get From Dictionary    ${instance_entry}    vrf
                                ${vrf_entry_exists}    ${vrf_entry}=    Run Keyword And Ignore Error
                                ...    Get From Dictionary
                                ...    ${instance_vrfs}
                                ...    ${vrf_name}
                                IF    "${vrf_entry_exists}" == "PASS"
                                    ${vrf_entry_ref}=    Set Variable    ${vrf_entry}
                                ELSE
                                    ${vrf_entry_ref}=    Create Dictionary
                                    ${af_dict}=    Create Dictionary
                                    Set To Dictionary    ${vrf_entry_ref}    address_family=${af_dict}
                                    Set To Dictionary    ${instance_vrfs}    ${vrf_name}=${vrf_entry_ref}
                                END

                                ${parsed_afs_exist}    ${parsed_afs}=    Run Keyword And Ignore Error
                                ...    Get From Dictionary
                                ...    ${parsed_vrf_data}
                                ...    address_family
                                IF    "${parsed_afs_exist}" == "PASS"
                                    FOR    ${af}    ${af_data}    IN    &{parsed_afs}
                                        ${vrf_afs}=    Get From Dictionary    ${vrf_entry_ref}    address_family
                                        ${af_entry_exists}    ${af_entry}=    Run Keyword And Ignore Error
                                        ...    Get From Dictionary
                                        ...    ${vrf_afs}
                                        ...    ${af}
                                        IF    "${af_entry_exists}" == "PASS"
                                            ${af_entry_ref}=    Set Variable    ${af_entry}
                                        ELSE
                                            ${af_entry_ref}=    Create Dictionary
                                            ${intf_dict}=    Create Dictionary
                                            Set To Dictionary    ${af_entry_ref}    eigrp_interface=${intf_dict}
                                            Set To Dictionary    ${vrf_afs}    ${af}=${af_entry_ref}
                                        END

                                        ${parsed_intfs_exist}    ${parsed_intfs}=    Run Keyword And Ignore Error
                                        ...    Get From Dictionary
                                        ...    ${af_data}
                                        ...    eigrp_interface
                                        IF    "${parsed_intfs_exist}" == "PASS"
                                            FOR    ${intf}    ${intf_data}    IN    &{parsed_intfs}
                                                ${af_intfs}=    Get From Dictionary    ${af_entry_ref}    eigrp_interface
                                                ${intf_entry_exists}    ${intf_entry}=    Run Keyword And Ignore Error
                                                ...    Get From Dictionary
                                                ...    ${af_intfs}
                                                ...    ${intf}
                                                IF    "${intf_entry_exists}" == "PASS"
                                                    ${intf_entry_ref}=    Set Variable    ${intf_entry}
                                                ELSE
                                                    ${intf_entry_ref}=    Create Dictionary
                                                    ${nbr_dict}=    Create Dictionary
                                                    Set To Dictionary    ${intf_entry_ref}    eigrp_nbr=${nbr_dict}
                                                    Set To Dictionary    ${af_intfs}    ${intf}=${intf_entry_ref}
                                                END

                                                ${parsed_nbrs_exist}    ${parsed_nbrs}=    Run Keyword And Ignore Error
                                                ...    Get From Dictionary
                                                ...    ${intf_data}
                                                ...    eigrp_nbr
                                                IF    "${parsed_nbrs_exist}" == "PASS"
                                                    ${intf_nbrs}=    Get From Dictionary    ${intf_entry_ref}    eigrp_nbr
                                                    FOR    ${nbr_ip}    ${nbr_data}    IN    &{parsed_nbrs}
                                                        ${empty}=    Create Dictionary
                                                        Set To Dictionary    ${intf_nbrs}    ${nbr_ip}=${empty}
                                                    END
                                                END
                                            END
                                        END
                                    END
                                END
                            END
                        END
                    END
                END
            END
        END

        Set To Dictionary    ${current_DUT_data}    eigrp_instance=${eigrp_instances}

        IF    ${learning} == ${False}
            Set To Dictionary
            ...    ${current_DUT_data}
            ...    vrf_command=${vrf_command}
            ...    vrf_output=${vrf_output}
            Set To Dictionary    ${current_DUT_data}    eigrp_neighbor_outputs=${eigrp_neighbor_outputs}
        END

        Set To Dictionary    ${gathered_device_data}    ${DUT_name}=${current_DUT_data}
    END

    RETURN    ${gathered_device_data}