*** Settings ***
Documentation       Description:
...                 * This test suite validates Enhanced Interior Gateway Routing Protocol (EIGRP) neighbor adjacencies on IOS-XE devices.
...                 * EIGRP is a dynamic routing protocol that forms neighbor relationships between routers to exchange routing information and maintain loop-free paths.
...                 * Stable EIGRP adjacencies are critical for control plane health because they directly impact route learning, convergence behavior, and the ability of the network to recover from failures.
...                 * If expected EIGRP neighbors are missing, the control plane may have incomplete topology information, which can lead to missing routes, suboptimal routing decisions, traffic blackholing, or application reachability issues across the data plane.
...                 * Validating that each expected adjacency exists helps ensure routing stability, predictable convergence, and consistent forwarding behavior for applications that depend on dynamic routing.
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
...                 * On each device, run *show vrf* and parse the output to determine the current VRF state used for validation context.
...                 * For each expected EIGRP instance defined in the input parameters, evaluate whether the instance is present in the parsed EIGRP neighbor hierarchy for the device.
...                 * For each expected VRF under each expected instance, run *show ip eigrp vrf {vrf} neighbors* and parse the output to build the current EIGRP neighbor state for only the expected schema elements.
...                 * For each expected address-family under each expected instance and VRF, evaluate whether the address-family container exists in the parsed neighbor data.
...                 * For each expected EIGRP interface under each expected instance, VRF, and address-family, evaluate whether the interface exists in the parsed neighbor data.
...                 * For each expected neighbor IP under each expected interface, evaluate whether the neighbor IP exists in the parsed neighbor data.
...                 * Record a passing result for each expected neighbor IP that exists at the expected instance, VRF, address-family, and interface location.
...                 * Record a failing result if any expected instance, VRF, address-family, interface, or neighbor IP is missing from the current device state.
...                 * Attach the full raw output of *show vrf* for each device to the final report.
...                 * Attach the full raw output of *show ip eigrp vrf {vrf} neighbors* for each evaluated VRF on each device to the final report.
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
...                 * Every expected EIGRP neighbor adjacency exists on each device for the expected instance, VRF, address-family, interface, and neighbor IP.
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
...                 * Any expected EIGRP instance is missing on any device.
...                 * Any expected VRF is missing under an expected EIGRP instance on any device.
...                 * Any expected address-family is missing under an expected instance and VRF on any device.
...                 * Any expected EIGRP interface is missing under an expected instance, VRF, and address-family on any device.
...                 * Any expected EIGRP neighbor IP is missing under an expected instance, VRF, address-family, and interface on any device.
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
${PASS_STR}    <p>All expected EIGRP neighbor adjacencies match the current device state, so this test case has passed.</p>
${FAIL_STR}    <p>One or more expected EIGRP neighbor adjacencies do not match the current device state, so this test case has failed.</p>


*** Test Cases ***
[IOS-XE] Verify EIGRP Neighbor Adjacencies
    [Documentation]    Verify EIGRP neighbor adjacencies (instance/VRF/address-family/interface/neighbor IP) on one or more IOS-XE devices.
    ${current_device_data}=    Gather Parameters
    Log    ${current_device_data}

    FOR    ${DUT_name}    ${DUT_data}    IN    &{DUTS}
        ${current_DUT_data}=    Get From Dictionary    ${current_device_data}    ${DUT_name}

        FOR    ${instance}    ${instance_data}    IN    &{DUT_data['instance']}
            ${instance_exists}    ${current_instance_data}=    Run Keyword And Ignore Error
            ...    Get From Dictionary
            ...    ${current_DUT_data['instance']}
            ...    ${instance}
            IF    "${instance_exists}" == "PASS"
                FOR    ${vrf_name}    ${vrf_data}    IN    &{instance_data['vrf']}
                    ${vrf_exists}    ${current_vrf_data}=    Run Keyword And Ignore Error
                    ...    Get From Dictionary
                    ...    ${current_instance_data['vrf']}
                    ...    ${vrf_name}
                    IF    "${vrf_exists}" == "PASS"
                        FOR    ${af}    ${af_data}    IN    &{vrf_data['address_family']}
                            ${af_exists}    ${current_af_data}=    Run Keyword And Ignore Error
                            ...    Get From Dictionary
                            ...    ${current_vrf_data['address_family']}
                            ...    ${af}
                            IF    "${af_exists}" == "PASS"
                                FOR    ${interface_name}    ${interface_data}    IN    &{af_data['eigrp_interface']}
                                    ${intf_exists}    ${current_intf_data}=    Run Keyword And Ignore Error
                                    ...    Get From Dictionary
                                    ...    ${current_af_data['eigrp_interface']}
                                    ...    ${interface_name}
                                    IF    "${intf_exists}" == "PASS"
                                        FOR    ${neighbor_ip}    ${neighbor_data}    IN    &{interface_data['eigrp_nbr']}
                                            ${nbr_exists}    ${current_nbr_data}=    Run Keyword And Ignore Error
                                            ...    Get From Dictionary
                                            ...    ${current_intf_data['eigrp_nbr']}
                                            ...    ${neighbor_ip}
                                            IF    "${nbr_exists}" == "PASS"
                                                Add Passing Result
                                                ...    new_result=<p>EIGRP neighbor adjacency for instance ${instance}, VRF ${vrf_name}, address-family ${af}, interface ${interface_name}, neighbor ${neighbor_ip} exists on device ${DUT_name} as expected.</p>
                                            ELSE
                                                Add Failing Result
                                                ...    new_result=<p>EIGRP neighbor adjacency for instance ${instance}, VRF ${vrf_name}, address-family ${af}, interface ${interface_name}, neighbor ${neighbor_ip} does not exist on device ${DUT_name}, which is not expected.</p>
                                            END
                                        END
                                    ELSE
                                        Add Failing Result
                                        ...    new_result=<p>EIGRP interface ${interface_name} for instance ${instance}, VRF ${vrf_name}, address-family ${af} does not exist on device ${DUT_name}, which is not expected.</p>
                                    END
                                END
                            ELSE
                                Add Failing Result
                                ...    new_result=<p>EIGRP address-family ${af} for instance ${instance}, VRF ${vrf_name} does not exist on device ${DUT_name}, which is not expected.</p>
                            END
                        END
                    ELSE
                        Add Failing Result
                        ...    new_result=<p>EIGRP VRF ${vrf_name} under instance ${instance} does not exist on device ${DUT_name}, which is not expected.</p>
                    END
                END
            ELSE
                Add Failing Result
                ...    new_result=<p>EIGRP instance ${instance} does not exist on device ${DUT_name}, which is not expected.</p>
            END
        END

        Add Formatted Text To Result
        ...    new_result=<p>The full output of command <i>${current_DUT_data['vrf_command']}</i> from device ${DUT_name} is shown below.</p>
        ...    device_name=${DUT_name}
        ...    command=${current_DUT_data['vrf_command']}
        ...    command_output=${current_DUT_data['vrf_output']}

        FOR    ${instance}    ${instance_data}    IN    &{current_DUT_data['instance']}
            FOR    ${vrf_name}    ${vrf_data}    IN    &{instance_data['vrf']}
                Add Formatted Text To Result
                ...    new_result=<p>The full output of command <i>${vrf_data['neighbors_command']}</i> from device ${DUT_name} is shown below.</p>
                ...    device_name=${DUT_name}
                ...    command=${vrf_data['neighbors_command']}
                ...    command_output=${vrf_data['neighbors_output']}
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
    [Documentation]    Gather parameters from devices
    [Tags]    robot:continue-on-failure
    [Arguments]    ${learning}=${False}
    ${gathered_device_data}=    Create Dictionary

    FOR    ${DUT_name}    ${DUT_data}    IN    &{DUTS}
        Select Device "${DUT_name}"

        # show vrf (Genie parsed)
        ${vrf_command}=    Set Variable    show vrf
        ${vrf_output}=    Run "${vrf_command}"
        Log    ${vrf_output}
        ${vrf_parsed}=    Parse Output "${vrf_output}" Using Parser "${vrf_command}" On Device "${DUT_name}"
        Log    ${vrf_parsed}

        ${current_DUT_data}=    Create Dictionary
        ${instances}=    Create Dictionary

        # Only gather what is defined in the expected schema (instances/vrfs/address-families/interfaces/neighbor IPs)
        FOR    ${instance}    ${instance_data}    IN    &{DUT_data['instance']}
            ${current_instance_data}=    Create Dictionary
            ${vrfs}=    Create Dictionary

            FOR    ${vrf_name}    ${vrf_data}    IN    &{instance_data['vrf']}
                # Validate VRF exists on device using parsed "show vrf"
                ${vrf_present}    ${vrf_present_data}=    Run Keyword And Ignore Error
                ...    Get From Dictionary
                ...    ${vrf_parsed['vrf']}
                ...    ${vrf_name}

                ${current_vrf_data}=    Create Dictionary
                ${address_families}=    Create Dictionary

                # show ip eigrp vrf <vrf> neighbors (Genie parsed)
                ${neighbors_command}=    Set Variable    show ip eigrp vrf ${vrf_name} neighbors
                ${neighbors_output}=    Run "${neighbors_command}"
                Log    ${neighbors_output}
                ${neighbors_parsed}=    Parse Output "${neighbors_output}" Using Parser "${neighbors_command}" On Device "${DUT_name}"
                Log    ${neighbors_parsed}

                # Build subset structure that matches schema exactly:
                # instance -> vrf -> address_family -> eigrp_interface -> eigrp_nbr -> neighbor_ip : {}
                FOR    ${af}    ${af_data}    IN    &{vrf_data['address_family']}
                    ${current_af_data}=    Create Dictionary
                    ${eigrp_interfaces}=    Create Dictionary

                    # Try to locate the expected instance/vrf/af in parsed neighbors data
                    ${inst_present}    ${inst_parsed}=    Run Keyword And Ignore Error
                    ...    Get From Dictionary
                    ...    ${neighbors_parsed['eigrp_instance']}
                    ...    ${instance}
                    IF    "${inst_present}" == "PASS"
                        ${vrf_container_present}    ${vrf_container}=    Run Keyword And Ignore Error
                        ...    Get From Dictionary
                        ...    ${inst_parsed['vrf']}
                        ...    ${vrf_name}
                        IF    "${vrf_container_present}" == "PASS"
                            ${af_container_present}    ${af_container}=    Run Keyword And Ignore Error
                            ...    Get From Dictionary
                            ...    ${vrf_container['address_family']}
                            ...    ${af}
                            IF    "${af_container_present}" == "PASS"
                                ${parsed_intfs_present}    ${parsed_intfs}=    Run Keyword And Ignore Error
                                ...    Get From Dictionary
                                ...    ${af_container}
                                ...    eigrp_interface
                                IF    "${parsed_intfs_present}" == "PASS"
                                    # Only include expected interfaces/neighbors from the jobfile schema
                                    FOR    ${interface_name}    ${interface_data}    IN    &{af_data['eigrp_interface']}
                                        ${current_intf_data}=    Create Dictionary
                                        ${nbrs}=    Create Dictionary

                                        ${intf_present}    ${parsed_intf}=    Run Keyword And Ignore Error
                                        ...    Get From Dictionary
                                        ...    ${parsed_intfs}
                                        ...    ${interface_name}
                                        IF    "${intf_present}" == "PASS"
                                            ${parsed_nbrs_present}    ${parsed_nbrs}=    Run Keyword And Ignore Error
                                            ...    Get From Dictionary
                                            ...    ${parsed_intf}
                                            ...    eigrp_nbr
                                            IF    "${parsed_nbrs_present}" == "PASS"
                                                FOR    ${neighbor_ip}    ${neighbor_data}    IN    &{interface_data['eigrp_nbr']}
                                                    ${nbr_present}    ${parsed_nbr}=    Run Keyword And Ignore Error
                                                    ...    Get From Dictionary
                                                    ...    ${parsed_nbrs}
                                                    ...    ${neighbor_ip}
                                                    IF    "${nbr_present}" == "PASS"
                                                        Set To Dictionary    ${nbrs}    ${neighbor_ip}=${EMPTY}
                                                    ELSE
                                                        # Keep schema key but indicate missing by not adding it (comparison will fail in test case)
                                                        # Intentionally do nothing here.
                                                        No Operation
                                                    END
                                                END
                                            END
                                        END

                                        Set To Dictionary    ${current_intf_data}    eigrp_nbr=${nbrs}
                                        Set To Dictionary    ${eigrp_interfaces}    ${interface_name}=${current_intf_data}
                                    END
                                END
                            END
                        END
                    END

                    Set To Dictionary    ${current_af_data}    eigrp_interface=${eigrp_interfaces}
                    Set To Dictionary    ${address_families}    ${af}=${current_af_data}
                END

                Set To Dictionary    ${current_vrf_data}    address_family=${address_families}

                IF    ${learning} == ${False}
                    Set To Dictionary    ${current_vrf_data}    neighbors_command=${neighbors_command}    neighbors_output=${neighbors_output}
                END

                # Only include the VRF in gathered structure if it exists in "show vrf" OR if it is expected (always expected here)
                # We still build it either way to preserve schema for comparison.
                Set To Dictionary    ${vrfs}    ${vrf_name}=${current_vrf_data}
            END

            Set To Dictionary    ${current_instance_data}    vrf=${vrfs}
            Set To Dictionary    ${instances}    ${instance}=${current_instance_data}
        END

        Set To Dictionary    ${current_DUT_data}    instance=${instances}

        IF    ${learning} == ${False}
            Set To Dictionary    ${current_DUT_data}    vrf_command=${vrf_command}    vrf_output=${vrf_output}
        END

        Set To Dictionary    ${gathered_device_data}    ${DUT_name}=${current_DUT_data}
    END

    RETURN    ${gathered_device_data}