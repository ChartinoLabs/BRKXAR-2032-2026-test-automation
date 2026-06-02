*** Settings ***
Documentation       Description:
...                 * This test suite validates Enhanced Interior Gateway Routing Protocol (EIGRP) neighbor adjacencies on IOS-XE devices.
...                 * EIGRP is a dynamic routing protocol that forms neighbor relationships between routers to exchange routing information and maintain loop-free paths.
...                 * Stable EIGRP adjacencies are critical for consistent route learning and fast convergence, helping prevent routing blackholes, intermittent reachability, and application performance degradation.
...                 * Because EIGRP neighbors are part of the routing control plane, missing or unexpected adjacencies can directly impact the routing table, forwarding decisions in the data plane, and overall network stability during steady-state operation or topology changes.
...                 * This validation ensures the device control plane reflects the expected neighbor presence per EIGRP instance, VRF, address-family, and interface, confirming the routing domain is operating as intended.
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
...                 * Genie parsers for *show vrf* and *show ip eigrp vrf {vrf} neighbors* are available for the target IOS-XE software version.
...                 * Expected EIGRP neighbor IP addresses are defined in the jobfile parameters under the hierarchy of EIGRP instance, VRF, address-family, and interface.
...
...                 Procedure:
...                 Connect to the following devices:
...
...                 {% for DUT_name in DUTS.keys() %}
...                 * {{ DUT_name }}
...                 {% endfor %}
...
...                 * Run *show vrf* on each device and parse the output to discover available VRFs.
...                 * For each discovered VRF on each device, run *show ip eigrp vrf {vrf} neighbors* and parse the output.
...                 * Build the current-state hierarchy for each device using parsed data in the following structure: EIGRP instance, VRF, address-family, EIGRP interface, and EIGRP neighbor IP.
...                 * For each device defined in the jobfile parameters, compare the expected hierarchy to the current-state hierarchy.
...                 * For each expected EIGRP instance, verify the instance exists in the current-state data for the device.
...                 * For each expected VRF under each expected instance, verify the VRF exists in the current-state data for the device.
...                 * For each expected address-family under each expected VRF, verify the address-family exists in the current-state data for the device.
...                 * For each expected EIGRP interface under each expected address-family, verify the interface exists in the current-state data for the device.
...                 * For each expected EIGRP neighbor IP under each expected interface, verify the neighbor IP is present in the current-state data for the device.
...                 * Add the full raw output of *show ip eigrp vrf {vrf} neighbors* for each VRF to the formatted results for troubleshooting visibility.
...                 * Add the full raw output of *show vrf* to the formatted results for each device to provide VRF context.
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
...                 * Every expected EIGRP instance exists on the device.
...                 * Every expected VRF exists under the expected EIGRP instance on the device.
...                 * Every expected address-family exists under the expected VRF on the device.
...                 * Every expected EIGRP interface exists under the expected address-family on the device.
...                 * Every expected EIGRP neighbor IP is present under the expected interface on the device.
...                 * The required parsed command outputs are available to be recorded in the results for each device and VRF.
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
...                 * Any expected EIGRP instance, VRF, address-family, or EIGRP interface is missing from the device current-state data.
...                 * Any expected EIGRP neighbor IP is not present on the device under the expected instance, VRF, address-family, and interface.
...                 * The command key or output key required to attach *show ip eigrp vrf {vrf} neighbors* output to the results is missing for any VRF.
...                 * The command output required to attach *show vrf* output to the results is missing for any device.
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
${PASS_STR}    <p>All expected EIGRP neighbor adjacencies match the current state on the device, so this test case has passed.</p>
${FAIL_STR}    <p>One or more expected EIGRP neighbor adjacencies do not match the current state on the device, so this test case has failed.</p>


*** Test Cases ***
[IOS-XE] Verify EIGRP Neighbor Adjacencies
    [Documentation]    Verify EIGRP neighbor adjacencies per EIGRP instance/VRF/address-family/interface/neighbor IP.
    ${current_device_data}=    Gather Parameters
    Log    ${current_device_data}

    FOR    ${DUT_name}    ${DUT_data}    IN    &{DUTS}
        ${current_DUT_data}=    Get From Dictionary    ${current_device_data}    ${DUT_name}

        ${expected_instances}=    Get From Dictionary    ${DUT_data}    eigrp_instance
        ${current_instances}=    Get From Dictionary    ${current_DUT_data}    eigrp_instance

        FOR    ${instance}    ${expected_instance_data}    IN    &{expected_instances}
            ${instance_exists}    ${current_instance_data}=    Run Keyword And Ignore Error
            ...    Get From Dictionary
            ...    ${current_instances}
            ...    ${instance}
            IF    "${instance_exists}" == "PASS"
                ${expected_vrfs}=    Get From Dictionary    ${expected_instance_data}    vrf
                ${current_vrfs}=    Get From Dictionary    ${current_instance_data}    vrf

                FOR    ${vrf_name}    ${expected_vrf_data}    IN    &{expected_vrfs}
                    ${vrf_exists}    ${current_vrf_data}=    Run Keyword And Ignore Error
                    ...    Get From Dictionary
                    ...    ${current_vrfs}
                    ...    ${vrf_name}
                    IF    "${vrf_exists}" == "PASS"
                        ${expected_afs}=    Get From Dictionary    ${expected_vrf_data}    address_family
                        ${current_afs}=    Get From Dictionary    ${current_vrf_data}    address_family

                        FOR    ${af}    ${expected_af_data}    IN    &{expected_afs}
                            ${af_exists}    ${current_af_data}=    Run Keyword And Ignore Error
                            ...    Get From Dictionary
                            ...    ${current_afs}
                            ...    ${af}
                            IF    "${af_exists}" == "PASS"
                                ${expected_interfaces}=    Get From Dictionary    ${expected_af_data}    eigrp_interface
                                ${current_interfaces}=    Get From Dictionary    ${current_af_data}    eigrp_interface

                                FOR    ${intf_name}    ${expected_intf_data}    IN    &{expected_interfaces}
                                    ${intf_exists}    ${current_intf_data}=    Run Keyword And Ignore Error
                                    ...    Get From Dictionary
                                    ...    ${current_interfaces}
                                    ...    ${intf_name}
                                    IF    "${intf_exists}" == "PASS"
                                        ${expected_nbrs}=    Get From Dictionary    ${expected_intf_data}    eigrp_nbr
                                        ${current_nbrs}=    Get From Dictionary    ${current_intf_data}    eigrp_nbr

                                        FOR    ${nbr_ip}    ${expected_nbr_data}    IN    &{expected_nbrs}
                                            ${nbr_exists}    ${current_nbr_data}=    Run Keyword And Ignore Error
                                            ...    Get From Dictionary
                                            ...    ${current_nbrs}
                                            ...    ${nbr_ip}
                                            IF    "${nbr_exists}" == "PASS"
                                                Add Passing Result
                                                ...    new_result=<p>EIGRP neighbor ${nbr_ip} is present as expected on device ${DUT_name} (instance ${instance}, VRF ${vrf_name}, address-family ${af}, interface ${intf_name}).</p>
                                            ELSE
                                                Add Failing Result
                                                ...    new_result=<p>EIGRP neighbor ${nbr_ip} is not present on device ${DUT_name} (instance ${instance}, VRF ${vrf_name}, address-family ${af}, interface ${intf_name}), which is not expected.</p>
                                            END
                                        END
                                    ELSE
                                        Add Failing Result
                                        ...    new_result=<p>EIGRP interface ${intf_name} is not present on device ${DUT_name} (instance ${instance}, VRF ${vrf_name}, address-family ${af}), which is not expected.</p>
                                    END
                                END
                            ELSE
                                Add Failing Result
                                ...    new_result=<p>EIGRP address-family ${af} is not present on device ${DUT_name} (instance ${instance}, VRF ${vrf_name}), which is not expected.</p>
                            END
                        END
                    ELSE
                        Add Failing Result
                        ...    new_result=<p>EIGRP VRF ${vrf_name} is not present on device ${DUT_name} for instance ${instance}, which is not expected.</p>
                    END

                    ${vrf_command_key}=    Set Variable    show_ip_eigrp_vrf_${vrf_name}_neighbors_command
                    ${vrf_output_key}=     Set Variable    show_ip_eigrp_vrf_${vrf_name}_neighbors_output
                    ${cmd_key_exists}    ${vrf_command}=    Run Keyword And Ignore Error
                    ...    Get From Dictionary
                    ...    ${current_DUT_data}
                    ...    ${vrf_command_key}
                    ${out_key_exists}    ${vrf_output}=    Run Keyword And Ignore Error
                    ...    Get From Dictionary
                    ...    ${current_DUT_data}
                    ...    ${vrf_output_key}
                    IF    "${cmd_key_exists}" == "PASS"
                        IF    "${out_key_exists}" == "PASS"
                            Add Formatted Text To Result
                            ...    new_result=<p>The full output of command <i>${vrf_command}</i> from device ${DUT_name} is shown below.</p>
                            ...    device_name=${DUT_name}
                            ...    command=${vrf_command}
                            ...    command_output=${vrf_output}
                        ELSE
                            Add Failing Result
                            ...    new_result=<p>Unable to add formatted output for device ${DUT_name} because output key ${vrf_output_key} was not found.</p>
                        END
                    ELSE
                        Add Failing Result
                        ...    new_result=<p>Unable to add formatted output for device ${DUT_name} because command key ${vrf_command_key} was not found.</p>
                    END
                END
            ELSE
                Add Failing Result
                ...    new_result=<p>EIGRP instance ${instance} is not present on device ${DUT_name}, which is not expected.</p>
            END
        END

        Add Formatted Text To Result
        ...    new_result=<p>The full output of command <i>${current_DUT_data['show_vrf_command']}</i> from device ${DUT_name} is shown below.</p>
        ...    device_name=${DUT_name}
        ...    command=${current_DUT_data['show_vrf_command']}
        ...    command_output=${current_DUT_data['show_vrf_output']}
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

        # show vrf (Genie Parser required)
        ${show_vrf_command}=    Set Variable    show vrf
        ${show_vrf_output}=    Run "${show_vrf_command}"
        Log    ${show_vrf_output}
        ${show_vrf_parsed}=    Parse Output "${show_vrf_output}" Using Parser "${show_vrf_command}" On Device "${DUT_name}"
        Log    ${show_vrf_parsed}

        # Build schema-aligned structure:
        # DUTS.<name>.eigrp_instance.<instance>.vrf.<vrf_name>.address_family.<address_family>.eigrp_interface.<interface_name>.eigrp_nbr.<neighbor_ip>
        ${eigrp_instances}=    Create Dictionary

        ${vrf_dict_exists}    ${vrf_dict}=    Run Keyword And Ignore Error
        ...    Get From Dictionary
        ...    ${show_vrf_parsed}
        ...    vrf
        IF    "${vrf_dict_exists}" == "PASS"
            FOR    ${vrf_name}    ${vrf_data}    IN    &{vrf_dict}
                # show ip eigrp vrf <vrf> neighbors (Genie Parser required)
                ${eigrp_nbr_command}=    Set Variable    show ip eigrp vrf ${vrf_name} neighbors
                ${eigrp_nbr_output}=    Run "${eigrp_nbr_command}"
                Log    ${eigrp_nbr_output}
                ${eigrp_nbr_parsed}=    Parse Output "${eigrp_nbr_output}" Using Parser "${eigrp_nbr_command}" On Device "${DUT_name}"
                Log    ${eigrp_nbr_parsed}

                ${parsed_instances_exists}    ${parsed_instances}=    Run Keyword And Ignore Error
                ...    Get From Dictionary
                ...    ${eigrp_nbr_parsed}
                ...    eigrp_instance
                IF    "${parsed_instances_exists}" == "PASS"
                    FOR    ${instance}    ${instance_data}    IN    &{parsed_instances}
                        ${instance_exists}    ${current_instance}=    Run Keyword And Ignore Error
                        ...    Get From Dictionary
                        ...    ${eigrp_instances}
                        ...    ${instance}
                        IF    "${instance_exists}" == "PASS"
                            ${instance_dict}=    Set Variable    ${current_instance}
                        ELSE
                            ${instance_dict}=    Create Dictionary    vrf=${EMPTY}
                            ${instance_vrfs}=    Create Dictionary
                            Set To Dictionary    ${instance_dict}    vrf=${instance_vrfs}
                            Set To Dictionary    ${eigrp_instances}    ${instance}=${instance_dict}
                        END

                        ${instance_vrfs}=    Get From Dictionary    ${instance_dict}    vrf
                        ${vrf_exists}    ${current_vrf}=    Run Keyword And Ignore Error
                        ...    Get From Dictionary
                        ...    ${instance_vrfs}
                        ...    ${vrf_name}
                        IF    "${vrf_exists}" == "PASS"
                            ${vrf_dict_out}=    Set Variable    ${current_vrf}
                        ELSE
                            ${vrf_dict_out}=    Create Dictionary
                            ${af_dict_out}=    Create Dictionary
                            Set To Dictionary    ${vrf_dict_out}    address_family=${af_dict_out}
                            Set To Dictionary    ${instance_vrfs}    ${vrf_name}=${vrf_dict_out}
                        END

                        ${parsed_vrfs_exists}    ${parsed_vrfs}=    Run Keyword And Ignore Error
                        ...    Get From Dictionary
                        ...    ${instance_data}
                        ...    vrf
                        IF    "${parsed_vrfs_exists}" == "PASS"
                            ${parsed_vrf_name_exists}    ${parsed_vrf_name_data}=    Run Keyword And Ignore Error
                            ...    Get From Dictionary
                            ...    ${parsed_vrfs}
                            ...    ${vrf_name}
                            IF    "${parsed_vrf_name_exists}" == "PASS"
                                ${parsed_afs_exists}    ${parsed_afs}=    Run Keyword And Ignore Error
                                ...    Get From Dictionary
                                ...    ${parsed_vrf_name_data}
                                ...    address_family
                                IF    "${parsed_afs_exists}" == "PASS"
                                    FOR    ${af}    ${af_data}    IN    &{parsed_afs}
                                        ${af_dict_out}=    Get From Dictionary    ${vrf_dict_out}    address_family
                                        ${af_exists}    ${current_af}=    Run Keyword And Ignore Error
                                        ...    Get From Dictionary
                                        ...    ${af_dict_out}
                                        ...    ${af}
                                        IF    "${af_exists}" == "PASS"
                                            ${af_out}=    Set Variable    ${current_af}
                                        ELSE
                                            ${af_out}=    Create Dictionary
                                            ${intf_dict_out}=    Create Dictionary
                                            Set To Dictionary    ${af_out}    eigrp_interface=${intf_dict_out}
                                            Set To Dictionary    ${af_dict_out}    ${af}=${af_out}
                                        END

                                        ${parsed_intfs_exists}    ${parsed_intfs}=    Run Keyword And Ignore Error
                                        ...    Get From Dictionary
                                        ...    ${af_data}
                                        ...    eigrp_interface
                                        IF    "${parsed_intfs_exists}" == "PASS"
                                            FOR    ${intf_name}    ${intf_data}    IN    &{parsed_intfs}
                                                ${intf_dict_out}=    Get From Dictionary    ${af_out}    eigrp_interface
                                                ${intf_exists}    ${current_intf}=    Run Keyword And Ignore Error
                                                ...    Get From Dictionary
                                                ...    ${intf_dict_out}
                                                ...    ${intf_name}
                                                IF    "${intf_exists}" == "PASS"
                                                    ${intf_out}=    Set Variable    ${current_intf}
                                                ELSE
                                                    ${intf_out}=    Create Dictionary
                                                    ${nbr_dict_out}=    Create Dictionary
                                                    Set To Dictionary    ${intf_out}    eigrp_nbr=${nbr_dict_out}
                                                    Set To Dictionary    ${intf_dict_out}    ${intf_name}=${intf_out}
                                                END

                                                ${parsed_nbrs_exists}    ${parsed_nbrs}=    Run Keyword And Ignore Error
                                                ...    Get From Dictionary
                                                ...    ${intf_data}
                                                ...    eigrp_nbr
                                                IF    "${parsed_nbrs_exists}" == "PASS"
                                                    FOR    ${nbr_ip}    ${nbr_data}    IN    &{parsed_nbrs}
                                                        ${nbr_dict_out}=    Get From Dictionary    ${intf_out}    eigrp_nbr
                                                        ${nbr_exists}    ${existing_nbr}=    Run Keyword And Ignore Error
                                                        ...    Get From Dictionary
                                                        ...    ${nbr_dict_out}
                                                        ...    ${nbr_ip}
                                                        IF    "${nbr_exists}" == "PASS"
                                                            # already present, do nothing
                                                            No Operation
                                                        ELSE
                                                            # Only keep neighbor IP key with empty dict (no other attributes per schema)
                                                            ${nbr_stub}=    Create Dictionary
                                                            Set To Dictionary    ${nbr_dict_out}    ${nbr_ip}=${nbr_stub}
                                                        END
                                                    END
                                                ELSE
                                                    # No neighbors for this interface in parsed output; keep schema without adding nbrs
                                                    No Operation
                                                END
                                            END
                                        ELSE
                                            # No interfaces found; keep schema without adding interfaces
                                            No Operation
                                        END
                                    END
                                ELSE
                                    # No address-families found; keep schema without adding afs
                                    No Operation
                                END
                            ELSE
                                # VRF not present in parsed EIGRP output; keep schema without adding details
                                No Operation
                            END
                        ELSE
                            # No VRF section in parsed EIGRP output; keep schema without adding details
                            No Operation
                        END
                    END
                ELSE
                    # No EIGRP instances in parsed output; nothing to add for this VRF
                    No Operation
                END

                IF    ${learning} == ${False}
                    ${cmd_key}=    Set Variable    show_ip_eigrp_vrf_${vrf_name}_neighbors_command
                    ${out_key}=    Set Variable    show_ip_eigrp_vrf_${vrf_name}_neighbors_output
                    Set To Dictionary    ${current_DUT_data}    ${cmd_key}=${eigrp_nbr_command}
                    Set To Dictionary    ${current_DUT_data}    ${out_key}=${eigrp_nbr_output}
                END
            END
        ELSE
            # No VRFs parsed; keep empty structures
            No Operation
        END

        Set To Dictionary    ${current_DUT_data}    eigrp_instance=${eigrp_instances}

        IF    ${learning} == ${False}
            Set To Dictionary
            ...    ${current_DUT_data}
            ...    show_vrf_command=${show_vrf_command}
            ...    show_vrf_output=${show_vrf_output}
        END

        Set To Dictionary    ${gathered_device_data}    ${DUT_name}=${current_DUT_data}
    END

    RETURN    ${gathered_device_data}