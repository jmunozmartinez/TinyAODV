/*
 * Copyright (c) 2008 Junseok Kim
 * Author: Junseok Kim <jskim@usn.konkuk.ac.kr> <http://usn.konkuk.ac.kr/~jskim>
 * Date: 2008/05/30
 * Version: 0.0.1
 * Published under the terms of the GNU General Public License (GPLv2).
 *
 *
 * Author of this version: Jaime Munoz Martinez <http://www.jaimemunozmartinez.com>
 * Date: 2014/11/19
 * Version 0.2.2
 * Published under the terms of the GNU General Public License (GPLv2).
 */

This is the implementation of the routing protocol AODV (Ad hoc On demand Distance Vector)
for TinyOS, called TinyAODV.
TinyOS is an open source Operating System designed for low-power wireless devices.
All Applications for TinyOS are written in nesC (network embedded systems C), 
a component-based event-driven programming language dialect of C optimized 
for the memory limits of sensor networks.

The author of the TinyAODV was Junseok Kim, but I (Jaime Munoz Martinez) debugged 
and enhanced version the TinyAODV implementation with RSSI and LQI information 
(from the PHY and MAC layers of IEEE 802.15.4) and I made the App to test TinyAODV 
and debugged the code in a real scenario with real nodes (Crossbow Iris motes)

I downloaded his code from his personal website. The code compiled, 
but it had TONS of errors and NOTHING in AODV protocol was working, 
not even the RREQ sending or the Route Table management.

The worst errors to detect were: 
- Null pointer exceptions
- Memory overwritten
- Buffer overrun/overflow
- WRONG Logic:
	· Wrong boolean flags
	· Bad logic in IF conditions
	· Piece of code that never was executed…

After debugging, and testing, finding new errors, solving them…the code finally worked,
and I focused into enhance the AODV implementation.

The App "TestAODV_RSSI_OnOff" is written in NesC.
At first it was simple program, the same for every node (I started working with six)
which sended messages from Source 1 to Destination 6.
The App evolved to debug the TinyAODV code:
- Different version off the App
- Different timers and counters
- Start sending messages from 1 to 6 until:
	· A Maximum number of Messages is reached
	· A timeout is triggered
- Show debugging and info messages 
	· Over the SerialPort
	· Leds
- Switchs off the mote (depends on NODE_ID, Timers…)

For the TESTs, I worked with Crossbow IRIS motes with Chip RF230

Tests: 
	- Measurement over the serial interface of the mote, with a USB-to-serial platform 
	connected to the PC. Only one at a time, because the motes were far away. I had
	problems in Xubuntu when I connected two or more basesations at the same time
	- To simulate Link breaks I Switched off the motes, moved the motes and implemented 
	some timers in the code to switch OFF-ON the motes by software
	- I used different configurations:
		· Multiple Link breaks combined, recovered…
		· Different topologies, and up to 4 Hop scenarios.
		

You can find more detail information in <http://www.jaimemunozmartinez.com/tinyaodv/>

 
---HELP---

Files: 

- You should modify the MAKE file and adapt it to your kind of mote (Iris, Micaz..)

- AODV_RSSI-LQI: 
TinyAODV protocol library files

- TestAODV_RSSI_OnOff: 
App to install in every node of the Network that works
differently depending on the NODE ID number of the device.
You should modify this file or create new ones with different parameters and options,
or configure the timers that switch OFF-ON the nodes to break the links of the networks.
You should install the App in every node and then set up the network.
	· Node 1: will be the source of the messages
	· Node 6: will be the destination of the transmission.
	· Rest of the nodes will be work just as routers
	
- TinyOS directories to place the Folders and files:
	/app/TestAODV_RSSI_OnOff
	/tos/lib/AODV
	/tos/lib/AODV_RSSI-LQI
	



