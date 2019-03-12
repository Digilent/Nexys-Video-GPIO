Nexys Video GPIO Demo
==============

This project is a Vivado demo using the Nexys Video's switches, LEDs, pushbuttons, onboard OLED display and USB UART bridge, written in VHDL and Verilog. When programmed onto the board, all eight of the switches are tied to their corresponding LEDs. Every time a switch is toggled, the LED directly above it will toggle with it. On startup the onboard OLED will display the full alphabet and numbers 0-9. After a second of displaying the alphabet/numbers the OLED will turn off for a second and then display the message “This is Digilent's Nexys Video”. 

To use the USB-UART bridge feature of this demo, the Nexys Video must be connected to a serial terminal on the computer it is connected to over the MicroUSB cable. For more information on how to set up and use a serial terminal, such as Tera Term or PuTTY, refer to [this tutorial](https://reference.digilentinc.com/learn/programmable-logic/tutorials/tera-term). Whenever the reset button or BTNC is pressed, the Basys 3 sends the line “Nexys Video GPIO/UART DEMO!” to the serial terminal. Whenever one of the D-pad buttons other than BTNC is pressed, the line “Button press detected!” is sent.

Important Warning
-------------
Before turning off or reprogramming your board, shut down the OLED display by pressing the CPU_RESET button.


Requirements
--------------
* **Nexys Video**:To purchase a Nexys Video, see the [Digilent Store](https://store.digilentinc.com/nexys-video-artix-7-fpga-trainer-board-for-multimedia-applications/)
* **Vivado 2018.2 Installation**:To set up Vivado, see the [Installing Vivado and Digilent Board Files Tutorial](https://reference.digilentinc.com/vivado/installing-vivado/start).
* **Serial Terminal Emulator Application**: For more information see the [Installing and Using a Terminal Emulator Tutorial](https://reference.digilentinc.com/learn/programmable-logic/tutorials/tera-term).
* **MicroUSB Cable**
* **Monitor with a VGA Port**
* **VGA Cable**
* **USB Mouse**
 
Demo Setup
--------------
1. Download and extract the most recent release ZIP archive from this repository's [Releases Page](https://github.com/Digilent/Nexys-Video-GPIO/releases).
2. Open the project in Vivado 2018.2 by double clicking on the included XPR file found at "\<archive extracted location\>/vivado_proj/Nexys-Video-GPIO.xpr".
3. In the Flow Navigator panel on the left side of the Vivado window, click **Open Hardware Manager**.
4. Plug the Nexys Video into the computer using a MicroUSB cable.
5. Open a serial terminal emulator (such as TeraTerm) and connect it to the Nexys Video's serial port, using a baud rate of 9600.
6. In the green bar at the top of the Vivado window, click **Open target**. Select **Auto connect** from the drop down menu.
7. In the green bar at the top of the Vivado window, click **Program device**.
8. In the Program Device Wizard, enter "\<archive extracted location\>vivado_proj/Nexys-Video-GPIO.runs/impl_1/GPIO_Demo.bit" into the "Bitstream file" field. Then click **Program**.
9. The demo will now be programmed onto the Nexys Video. See the Description section of this README to learn how to interact with this demo.

Next Steps
--------------
This demo can be used as a basis for other projects, either by adding sources included in the demo's release to those projects, or by modifying the sources in the release project.

Check out the Nexys Video's [Resource Center](https://reference.digilentinc.com/reference/programmable-logic/nexys-video/start) to find more documentation, demos, and tutorials.

For technical support or questions, please post on the [Digilent Forum](https://forum.digilentinc.com).

Additional Notes
--------------
For more information on how this project is version controlled, refer to the [Digilent Vivado Scripts Repository](https://github.com/digilent/digilent-vivado-scripts)

<!--- 03/12/2019 (ArtVVB): Validated in Hardware with 2018.2 --->