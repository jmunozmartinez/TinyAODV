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

#define AODV_DEBUG  1
#include "printf.h"
//#include "AODV.h"

module AODV_M {
  provides {
    interface SplitControl;
    interface AMSend[am_id_t id];
    interface Receive[uint8_t id];
  }
  
  uses {
    interface SplitControl as AMControl;
    interface Timer<TMilli> as AODVTimer;
    interface Timer<TMilli> as RREQTimer;
    interface Timer<TMilli> as RREPTimer;
    interface Timer<TMilli> as RERRTimer;
    interface Leds;
    interface Random;
    interface AMPacket;
    interface Packet;
    interface AMSend as SendRREQ;
    interface AMSend as SendRREP;
    interface AMSend as SendRERR;
    interface Receive as ReceiveRREQ;
    interface Receive as ReceiveRREP;
    interface Receive as ReceiveRERR;
    interface AMSend as SubSend;
    interface Receive as SubReceive;
    interface PacketAcknowledgements;
    
// Interface to get RSSI from messages
#ifdef __CC2420_H__
  	interface CC2420Packet;
#elif defined(TDA5250_MESSAGE_H)
  	interface Tda5250Packet;    
#else
  	interface PacketField<uint8_t> as PacketRSSI;
  	interface PacketField<uint8_t> as PacketLinkQuality;
  	interface PacketField<uint8_t> as PacketTransmitPower;
#endif 
//
  }
}

implementation {
  
  message_t rreq_msg_;
  message_t rrep_msg_;
  message_t rerr_msg_;
  message_t aodv_msg_;
  message_t app_msg_;
  
  message_t* p_rreq_msg_;
  message_t* p_rrep_msg_;
  message_t* p_rerr_msg_;
  message_t* p_aodv_msg_;
  message_t* p_app_msg_;
  
  uint8_t rreq_seq_ = 0;
  
  bool send_pending_    = FALSE;
  bool rreq_pending_    = FALSE;
  bool rrep_pending_    = FALSE;
  bool rerr_pending_    = FALSE;
  bool msg_pending_ = FALSE;
  
  uint8_t rreq_retries_    = AODV_RREQ_RETRIES;
  uint8_t rrep_retries_    = AODV_RREP_RETRIES;
  uint8_t rerr_retries_    = AODV_RERR_RETRIES;
  uint8_t msg_retries_     = AODV_MSG_RETRIES;
  
  AODV_ROUTE_TABLE route_table_[AODV_ROUTE_TABLE_SIZE];
  AODV_RREQ_CACHE rreq_cache_[AODV_RREQ_CACHE_SIZE];
  
  //Declaration of functions
  uint16_t getRssi(message_t *msg);
  uint16_t getLQI(message_t *msg);
  uint16_t getTxPower(message_t *msg); //not Work
  //Declaration of value of RSSI, LQI and TxPower
  uint16_t RssiValue; 	// AM_RSSI_THRESHOLD = 10
  uint8_t LQIvalue;			// AM_LQI_THRESHOLD = 230,
  uint16_t TxPower;
  
  bool sendRREQ( am_addr_t dest, bool forward );
  task void resendRREQ();
  
  bool sendRREP( am_addr_t dest, bool forward );
  task void resendRREP();
  
  bool sendRERR( am_addr_t dest, am_addr_t src, bool forward );
  task void resendRERR();
  
  error_t forwardMSG( message_t* msg, am_addr_t nextHop, uint8_t len );
  void resendMSG();
  
  uint8_t get_rreq_cache_index( am_addr_t src, am_addr_t dest );
  bool is_rreq_cached( aodv_rreq_hdr* msg );
  bool add_rreq_cache( uint8_t seq, am_addr_t dest, am_addr_t src, uint8_t hop );
  void del_rreq_cache( uint8_t id );
  task void update_rreq_cache();
  
  uint8_t get_route_table_index( am_addr_t dest );
  bool add_route_table( uint8_t seq, am_addr_t dest, am_addr_t nexthop, uint8_t hop );
  void del_route_table( am_addr_t dest );
  am_addr_t get_next_hop( am_addr_t dest );
  
//#if AODV_DEBUG
  void print_route_table();
  void print_rreq_cache();
//#endif
  
  command error_t SplitControl.start() {
    int i;
    
    p_rreq_msg_     = &rreq_msg_;
    p_rrep_msg_     = &rrep_msg_;
    p_rerr_msg_     = &rerr_msg_;
    p_aodv_msg_     = &aodv_msg_;
    p_app_msg_      = &app_msg_;
    
    for(i = 0; i< AODV_ROUTE_TABLE_SIZE; i++) {
      route_table_[i].seq  = 0;
      route_table_[i].dest = INVALID_NODE_ID;
      route_table_[i].next = INVALID_NODE_ID;
      route_table_[i].hop  = 0;
      route_table_[i].Rquality = 0;
  		route_table_[i].precursor = 0;
  		route_table_[i].valid = FALSE;
    }
    
    for(i = 0; i< AODV_RREQ_CACHE_SIZE; i++) {
      rreq_cache_[i].seq  = 0;
      rreq_cache_[i].dest = INVALID_NODE_ID;
      rreq_cache_[i].src  = INVALID_NODE_ID;
      rreq_cache_[i].hop  = 0;
  		rreq_cache_[i].Rqual = 0;
    }
    
    call AMControl.start();
    
    return SUCCESS;
  } // start
  
  
  command error_t SplitControl.stop() {
    call AMControl.stop();
    return SUCCESS;
  }
  
  
  event void AMControl.startDone( error_t e ) {
    if ( e == SUCCESS ) {
      call AODVTimer.startPeriodic( AODV_DEFAULT_PERIOD );
      signal SplitControl.startDone(e);
    } else {
      call AMControl.start();
    }
  }
  
  
  event void AMControl.stopDone(error_t e){
    call AODVTimer.stop();
    signal SplitControl.stopDone(e);
  }
  
  
  //--------------------------------------------------------------------------
  //  sendRREQ: This broadcasts the RREQ to find the path from the source to
  //  the destination.
  //--------------------------------------------------------------------------
  bool sendRREQ( am_addr_t dest, bool forward ) {
    aodv_rreq_hdr* aodv_hdr = (aodv_rreq_hdr*)(p_rreq_msg_->data);
    
    //dbg("AODV", "%s\t AODV: sendRREQ() dest: %d\n", sim_time_string(), dest);
    //call Leds.led0Toggle();
    if( rreq_pending_ == TRUE ) {
      return FALSE;
    }
    
    if( forward == FALSE ) { // generate the RREQ for the first time
      aodv_hdr->seq      = rreq_seq_++;
      aodv_hdr->dest     = dest;
      aodv_hdr->src      = call AMPacket.address();
      aodv_hdr->hop      = 1;
      aodv_hdr->Maxhop 	= 1;
  		aodv_hdr->numRetries = 3;
  		aodv_hdr->qual = 0;
      add_rreq_cache( aodv_hdr->seq, aodv_hdr->dest, aodv_hdr->src, 0 );
      
    } else { // forward the RREQ
      aodv_hdr->hop++;
    }
    
    if (!send_pending_) { //If there isn't messages pending, we send RREQ
      if( call SendRREQ.send(TOS_BCAST_ADDR, p_rreq_msg_, 
                                    AODV_RREQ_HEADER_LEN) == SUCCESS) {
        //dbg("AODV", "%s\t AODV: sendRREQ()\n", sim_time_string());
        send_pending_ = TRUE;
        //call Leds.led0Toggle(); //RREQ SENT!!!
        printf("*AODV_M* -> Sent RREQ: from %d\n", TOS_NODE_ID);
    		printfflush();
        return TRUE;
      }
    }
    
    rreq_pending_ = TRUE;
    rreq_retries_ = AODV_RREQ_RETRIES;
    //call Leds.led2Toggle();
    return FALSE;
  }
  
  
  //--------------------------------------------------------------------------
  //  sendRREP: This forwards the RREP to the nexthop of the source of RREQ
  //  to establish and inform the route.
  //--------------------------------------------------------------------------
  bool sendRREP( am_addr_t dest, bool forward ){
    
    //dbg("AODV_DBG", "%s\t AODV: sendRREP() dest: %d send_pending_: %d\n", 
    //                                  sim_time_string(), dest, send_pending_);
    
    if ( !send_pending_ ) {
      call PacketAcknowledgements.requestAck(p_rrep_msg_);
      if( call SendRREP.send(dest, p_rrep_msg_, 
                                           AODV_RREP_HEADER_LEN) == SUCCESS) {
        //dbg("AODV", "%s\t AODV: sendRREP() to %d\n", sim_time_string(), dest);
        printf("*AODV_M* -> Sent RREP: to %d from %d\n", dest, TOS_NODE_ID);
    		printfflush();        
        send_pending_ = TRUE;
        return TRUE;
      }
    }
    
    rrep_pending_ = TRUE;
    rrep_retries_ = AODV_RREP_RETRIES;
    return FALSE;
  }
  
  
  //--------------------------------------------------------------------------
  //  sendRERR: If the node fails to transmit a message over the retransmission
  //  limit, it will send RERR to the source node of the message.
  //--------------------------------------------------------------------------
  bool sendRERR( am_addr_t dest, am_addr_t src, bool forward ){
    aodv_rerr_hdr* aodv_hdr = (aodv_rerr_hdr*)(p_rerr_msg_->data);
    am_addr_t target;
    
    if (forward == FALSE) {
    rerr_pending_ = FALSE;
    return TRUE;
    }
    
    //dbg("AODV_DBG", "%s\t AODV: sendRERR() dest: %d\n", sim_time_string(), dest);
    //call Leds.led1Toggle();
    aodv_hdr->dest = dest;
    aodv_hdr->src = src; //Source of the original message, destination of RERR
    
    target = get_next_hop( src );
    
    if (target == INVALID_NODE_ID){
    		printf("*AODV_M* -> CAN'T send RRER: to %d \n", target);
    		printfflush();
    		rerr_pending_ = TRUE;
    		rerr_retries_ = AODV_RERR_RETRIES;
    		return FALSE;
    } 
    
    if (!send_pending_) {
    	call PacketAcknowledgements.requestAck(p_rerr_msg_);
      if( call SendRERR.send(target, p_rerr_msg_, AODV_RERR_HEADER_LEN) == SUCCESS) {
        //dbg("AODV", "%s\t AODV: sendRREQ() to %d\n", sim_time_string(), target);
        printf("*AODV_M* -> Sent RRER: to %d from %d\n", target, TOS_NODE_ID);
    		printfflush();
        send_pending_ = TRUE;
        //rerr_pending_ = FALSE;
        return TRUE;
      }
    }
    
    rerr_pending_ = TRUE;
    rerr_retries_ = AODV_RERR_RETRIES;
    return FALSE;
  }

  //--------------------------------------------------------------------------
  //  tasks:
  //--------------------------------------------------------------------------  
  
  task void resendRREQ() {
    //dbg("AODV", "%s\t AODV: resendRREQ()\n", sim_time_string());
    //call Leds.led0Toggle();
    if(rreq_retries_ <= 0){
      rreq_pending_ = FALSE;
      return;
    }
    rreq_retries_--;
    
    if ( !send_pending_ ) {
      if( call SendRREQ.send(TOS_BCAST_ADDR, p_rreq_msg_, AODV_RREQ_HEADER_LEN) ) {
        send_pending_ = TRUE;
        rreq_pending_ = FALSE;
        printf("*AODV_M* -> Sent RREQ again: %d retries left\n", rreq_retries_);
    		printfflush();
      }
    }
  }
  
  
  task void resendRREP(){
    am_addr_t dest = call AMPacket.destination( p_rrep_msg_ );
    if( rrep_retries_ == 0 ) {
      rrep_pending_ = FALSE;
      return;
    }
    rrep_retries_--;
    
    if ( !send_pending_ ) {
      call PacketAcknowledgements.requestAck( p_rrep_msg_ );
      if( call SendRREP.send( dest, 
                               p_rrep_msg_, AODV_RREP_HEADER_LEN) == SUCCESS) {
        //dbg("AODV", "%s\t AODV: resendRREP() to %d\n", sim_time_string(), dest);
        printf("*AODV_M* -> Sent RREP to %d again: %d retries left\n", dest, rrep_retries_);
    		printfflush();
        send_pending_ = TRUE;
        rrep_pending_ = FALSE;
      }
    }
  }
  
  
  task void resendRERR(){
    am_addr_t dest = call AMPacket.destination( p_rerr_msg_ );
    if( rerr_retries_ == 0 ) {
      rerr_pending_ = FALSE;
      return;
    }
    rerr_retries_--;
    
    if ( !send_pending_ ) {
      call PacketAcknowledgements.requestAck( p_rerr_msg_ );
      if( call SendRERR.send( dest, 
                               p_rerr_msg_, AODV_RERR_HEADER_LEN) == SUCCESS) {
        //dbg("AODV", "%s\t AODV: resendRERR() to %d\n", sim_time_string());
        printf("*AODV_M* -> Sent RRER to %d again: %d retries left\n", dest, rerr_retries_);
    		printfflush();
        send_pending_ = TRUE;
        rerr_pending_ = FALSE;
      }
    }
  }
  
  
  //--------------------------------------------------------------------------
  //  resendMSG: This is triggered by the timer. If the forward_retries_ equals
  //  zero, the retransmission will be canceled. Or, the cached message will
  //  be retransmitted.
  //--------------------------------------------------------------------------
  void resendMSG() {
    if( msg_retries_ == 0 ) {
      msg_pending_ = FALSE;
      return;
    }
    msg_retries_--;
    call PacketAcknowledgements.requestAck( p_aodv_msg_ );
    if( !send_pending_ ) {
      if( call SubSend.send( call AMPacket.destination(p_aodv_msg_),
                        p_aodv_msg_,
                        call Packet.payloadLength(p_aodv_msg_) ) == SUCCESS ) {
        //dbg("AODV", "%s\t AODV: resendMSG() broadcast\n", sim_time_string());
        am_addr_t destt = call AMPacket.destination(p_aodv_msg_);
        printf("*AODV_M* -> Sent MSG to %d again: %d retries left\n", destt, msg_retries_);
    		printfflush();
        send_pending_ = TRUE;
        msg_pending_ = FALSE;
      }
    }
  }
  
  
  uint8_t get_rreq_cache_index( am_addr_t src, am_addr_t dest ){
    int i;
    for( i=0 ; i < AODV_RREQ_CACHE_SIZE ; i++ ) {
      if( rreq_cache_[i].src == src && rreq_cache_[i].dest == dest ) {
        return i;
      }
      return INVALID_INDEX;
    }
  }
  
  
  bool is_rreq_cached( aodv_rreq_hdr* rreq_hdr ) {
    int i;
    
    for( i=0; i < AODV_RREQ_CACHE_SIZE ; i++ ) {
      if( rreq_cache_[i].dest == INVALID_NODE_ID ) {
        return TRUE;
      }
      if( rreq_cache_[i].src == rreq_hdr->src && rreq_cache_[i].dest == rreq_hdr->dest ) {
        if( rreq_cache_[i].seq < rreq_hdr->seq || 
           ( rreq_cache_[i].seq == rreq_hdr->seq && rreq_cache_[i].hop > rreq_hdr->hop )) {
          // this is a newer rreq
	  return TRUE;
        } else {
          return FALSE;
        }
      }
    }
    return TRUE;
  } //
  
  
  bool add_rreq_cache( uint8_t seq, am_addr_t dest, am_addr_t src, uint8_t hop ) {
    uint8_t i;
    uint8_t idLine = AODV_RREQ_CACHE_SIZE;
    
    for( i=0; i < AODV_RREQ_CACHE_SIZE-1 ; i++ ) {
      if( rreq_cache_[i].src == src && rreq_cache_[i].dest == dest ) {
        idLine = i;
        break;
      }
      if( rreq_cache_[i].dest == INVALID_NODE_ID )
      break;
    }
    
    if( idLine != AODV_RREQ_CACHE_SIZE ) {
      if( rreq_cache_[i].src == src && rreq_cache_[i].dest == dest ) {
        if( rreq_cache_[idLine].seq < seq || rreq_cache_[idLine].hop > hop ) {
          rreq_cache_[idLine].seq = seq;
          rreq_cache_[idLine].hop = hop;
          rreq_cache_[i].ttl  = AODV_RREQ_CACHE_TTL;
          print_rreq_cache();
          return TRUE;
        }
      }
    } else if( i != AODV_RREQ_CACHE_SIZE ) {
      rreq_cache_[i].seq  = seq;
      rreq_cache_[i].dest = dest;
      rreq_cache_[i].src  = src;
      rreq_cache_[i].hop  = hop;
      rreq_cache_[i].ttl  = AODV_RREQ_CACHE_TTL;
      print_rreq_cache();
      return TRUE;
    }
    
    //print_rreq_cache();
    return FALSE;
  }
  
  
  void del_rreq_cache( uint8_t ident ) {
    uint8_t i;
    
    for(i = ident; i< AODV_ROUTE_TABLE_SIZE-1; i++) {
      if(rreq_cache_[i+1].dest == INVALID_NODE_ID) {
        break;
      }
      rreq_cache_[i] = rreq_cache_[i+1];
      //rreq_cache_[i].dest = INVALID_NODE_ID;
    	//rreq_cache_[i].src = INVALID_NODE_ID;
    	//rreq_cache_[i].seq  = 0;
    	//rreq_cache_[i].hop  = 0;
    }
    
    rreq_cache_[i].dest = INVALID_NODE_ID;
    rreq_cache_[i].src = INVALID_NODE_ID;
    rreq_cache_[i].seq  = 0;
    rreq_cache_[i].hop  = 0;
    
    print_rreq_cache();
  }
  
  
  //--------------------------------------------------------------------------
  //  update_rreq_cache: This is triggered periodically by the timer.
  //  If the ttl of a rreq_cache entity equals to zero, the entity will be 
  //  removed.
  //--------------------------------------------------------------------------
  task void update_rreq_cache() {
    uint8_t i;
    for( i=0 ; i < AODV_RREQ_CACHE_SIZE-1 ; i++ ) {
      if( rreq_cache_[i].dest == INVALID_NODE_ID )
	break;
      else if( rreq_cache_[i].ttl-- == 0 )
        del_rreq_cache(i);
    }
  }
  
  
  //--------------------------------------------------------------------------
  //  get_route_table_index: Return the index which is correspoing to
  //  the destination
  //--------------------------------------------------------------------------
  uint8_t get_route_table_index( am_addr_t dest ) {
    int i;
    for(i=0; i< AODV_ROUTE_TABLE_SIZE; i++) {
      if(route_table_[i].dest == dest)
 				printf("***AODV: ROUTE_TABLE i:%u dest:%d returned\n", i, route_table_[i].dest);
    		printfflush();
        return i;
    }
    printf("***AODV: ROUTE_TABLE fail to get index of dest %d\n", dest);
    printfflush();
    return INVALID_INDEX;
  } //
 
  
  
  void del_route_table( am_addr_t dest ) {
    uint8_t i;
    uint8_t idRT = get_route_table_index( dest );
    
    
    
    //dbg("AODV", "%s\t AODV: del_route_table() dest:%d\n",
      //                                 sim_time_string(), dest);
    if (idRT != INVALID_INDEX) {
    	for(i = idRT; i< AODV_ROUTE_TABLE_SIZE-1; i++) {
      	if(route_table_[i+1].dest == INVALID_NODE_ID) {
      	  break;
      	}
      	printf("***AODV: ROUTE_TABLE FOR-IF deleted i:%u dest:%d and UPDATED \n", i, route_table_[i].dest);
    		printfflush();
      	route_table_[i] = route_table_[i+1];
      	//route_table_[i].dest = INVALID_NODE_ID;
    		//route_table_[i].next = INVALID_NODE_ID;
    		//route_table_[i].seq  = 0;
    		//route_table_[i].hop  = 0;    	
    	}	
    	printf("***AODV: ROUTE_TABLE deleted i:%u dest:%d \n", i, route_table_[i].dest);
    	printfflush();
    	route_table_[i].dest = INVALID_NODE_ID;
    	route_table_[i].next = INVALID_NODE_ID;
    	route_table_[i].seq  = 0;
    	route_table_[i].hop  = 0;    
    	print_route_table();
  	} else {
  	printf("***AODV: FAIL to delete %d from ROUTE_TABLE\n", dest);
    printfflush();  	
  	}
  }
  
  
  //--------------------------------------------------------------------------
  //  add_route_table: If a route information is a new or fresh one, it is 
  //  added to the route table.
  //--------------------------------------------------------------------------
  bool add_route_table( uint8_t seq, am_addr_t dest, am_addr_t nexthop, uint8_t hop ) {
    uint8_t i;
    uint8_t idRTSize = AODV_ROUTE_TABLE_SIZE;
    
    //dbg("AODV_DBG", "%s\t AODV: add_route_table() seq:%d dest:%d next:%d hop:%d\n",
      //                              sim_time_string(), seq, dest, nexthop, hop);
    for( i=0 ; i < AODV_ROUTE_TABLE_SIZE-1 ; i++ ) {
      if( route_table_[i].dest == dest ) {
        idRTSize = i;
        //printf("***AODV: destination found in ROUTE TABLE i: %d: dest: %d next: %d seq: %d hop: %d \n", i, route_table_[i].dest, route_table_[i].next, route_table_[i].seq, route_table_[i].hop );
    		//printfflush();
        break;
      }
      if( route_table_[i].dest == INVALID_NODE_ID ) {
        //printf("***AODV: ROUTE TABLE i: %d END OF THE TABLE \n", i);
    		//printfflush();
        break;
      }
    }
    
    if( idRTSize != AODV_ROUTE_TABLE_SIZE ) {  // Si el destino estaba en la tabla
      if( route_table_[idRTSize].next == nexthop ) { // Si el nexthop es el mismo
        if( route_table_[idRTSize].seq < seq || route_table_[idRTSize].hop > hop ) {
          route_table_[idRTSize].seq = seq; //Seq menor o Hop mayor, se actualiza
          route_table_[idRTSize].hop = hop;
          //route_table_[idRTSize].ttl = 0;
          //printf("***AODV: ROUTE TABLE i: %d Seq and Hop UPDATED \n", idRTSize);
    			//printfflush();
          print_route_table();
          return TRUE;
        }
      }
    } else if( i != AODV_ROUTE_TABLE_SIZE ) { //No se ha encontrado, si no está 
      route_table_[i].seq  = seq;							// la tabla llena, se añade. 
      route_table_[i].dest = dest;
      route_table_[i].next = nexthop;
      route_table_[i].hop  = hop;
      //route_table_[i].ttl = 0;
      //printf("***AODV: ROUTE TABLE added i: %d: dest: %d next: %d seq: %d hop: %d \n", i, dest, nexthop, seq, hop);
      //printfflush();
      print_route_table();
      return TRUE;
    } 
    //printf("***AODV: ROUTE TABLE not UPDATED \n");
    //printfflush();
    print_route_table();
    return FALSE;
    //print_route_table();
  }
  
  
  //--------------------------------------------------------------------------
  //  get_next_hop: Return the nexthop node address of the message if the 
  //  address exists in the route table.
  //--------------------------------------------------------------------------
  am_addr_t get_next_hop( am_addr_t dest ) {
    int i;
    for( i=0 ; i < AODV_ROUTE_TABLE_SIZE ; i++ ) {
      if(route_table_[i].dest == dest) {
        return route_table_[i].next;
      }
    }
    return INVALID_NODE_ID;
  }
  
  
  //--------------------------------------------------------------------------
  //  forwardMSG: The node forwards a message to the next-hop node if the 
  //  target of the message is not itself.
  //--------------------------------------------------------------------------
  error_t forwardMSG( message_t* p_msg, am_addr_t nexthop, uint8_t len ) {
    aodv_msg_hdr* aodv_hdr = (aodv_msg_hdr*)(p_msg->data);
    aodv_msg_hdr* msg_aodv_hdr = (aodv_msg_hdr*)(p_aodv_msg_->data);
    uint8_t i;
    
    if ( msg_pending_ ) {
      //dbg("AODV", "%s\t AODV: forwardMSG() msg_pending_\n", sim_time_string());
      return FAIL;
    }
    //dbg("AODV_DBG", "%s\t AODV: forwardMSG() try to forward to %d \n", 
    //                                                sim_time_string(), nexthop);
    
    // forward MSG
    msg_aodv_hdr->dest = aodv_hdr->dest;
    msg_aodv_hdr->src  = aodv_hdr->src;
    msg_aodv_hdr->app  = aodv_hdr->app;
    
    for( i=0 ; i < len-AODV_MSG_HEADER_LEN ; i++ ) {
      msg_aodv_hdr->data[i] = aodv_hdr->data[i];
    }
    
    call PacketAcknowledgements.requestAck(p_aodv_msg_);
    
    if( call SubSend.send(nexthop, p_aodv_msg_, len) == SUCCESS ) {
      //dbg("AODV", "%s\t AODV: forwardMSG() send MSG to: %d\n", 
       //                                          sim_time_string(), nexthop);
      printf("*AODV_M* -> SUBSEND in forwardMSG(): dest: %d id: %d len: %d nexthop: %d\n", msg_aodv_hdr->dest, msg_aodv_hdr->app, len, nexthop);
    	printfflush();
      msg_retries_ = AODV_MSG_RETRIES;
      msg_pending_ = TRUE;
    } else {
      //dbg("AODV", "%s\t AODV: forwardMSG() fail to send\n", sim_time_string());
      printf("*AODV_M* -> SUBSEND in forwardMSG() FAIL!");
    	printfflush();
      msg_pending_ = FALSE;
    }
    return SUCCESS;
  }
  
  
  //--------------------------------------------------------------------------
  //  AMSend.send: If there is a route to the destination, the message will be 
  //  sent to the next-hop node for the destination. Or, the node will broadcast
  //  the RREQ.
  //--------------------------------------------------------------------------
  command error_t AMSend.send[am_id_t id](am_addr_t addr, message_t* msg, uint8_t len) {
    
    uint8_t i;
    aodv_msg_hdr* aodv_hdr = (aodv_msg_hdr*)(p_aodv_msg_->data);
    am_addr_t nexthop = get_next_hop( addr );
    am_addr_t me = call AMPacket.address();
    //call Leds.led1Toggle();
    
    //dbg("AODV", "%s\t AODV: AMSend.send() dest: %d id: %d len: %d nexthop: %d\n", 
    //            sim_time_string(), addr, id, len, nexthop);
    
    if( addr == me ) {
      return SUCCESS;
    }
    /* If the next-hop node for the destination does not exist, the RREQ will be
       broadcasted */
    if( nexthop == INVALID_NODE_ID ) {
      //call Leds.led1Toggle();
      //printf("*AODV_M* -> Sent AODV message: nexthop %d UNKNOWN\n", nexthop);
    	//printfflush();
      if( !rreq_pending_ ) {
        //dbg("AODV", "%s\t AODV: AMSend.send() a new destination\n", 
          //                                                   sim_time_string());
        //call Leds.led2Toggle();
        sendRREQ( addr, FALSE );
        return SUCCESS;
      }
      return FAIL;
    }
    //dbg("AODV", "%s\t AODV: AMSend.send() there is a route to %d\n", 
    //                                                    sim_time_string(), addr);
    
    
    aodv_hdr->dest = addr;
    aodv_hdr->src  = me;
    aodv_hdr->app  = id;
    //aodv_hdr->app  = 1;
    //printf("*AODV_M* -> Sent AODV message: dest: %d id: %d len: %d nexthop: %d\n", addr, id, len, nexthop);
    //printfflush();
    for( i=0;i<len;i++ ) {
      aodv_hdr->data[i] = msg->data[i];
    }
    
    call PacketAcknowledgements.requestAck(p_aodv_msg_);
    //Now we send again the packet to the next hop in the Route
    if( !send_pending_ ) {
      if( call SubSend.send( nexthop, p_aodv_msg_, len + AODV_MSG_HEADER_LEN ) == SUCCESS ) {
        send_pending_ = TRUE;
        printf("*AODV_M* -> SUBSEND in AMSend: dest: %d id: %d len: %d nexthop: %d\n", addr, aodv_hdr->app, len, nexthop);
    		printfflush();
    		msg_retries_ = AODV_MSG_RETRIES; //reset the value of the variable
      	msg_pending_ = TRUE;
        return SUCCESS;
      }
      //This code is never executed
      //msg_retries_ = AODV_MSG_RETRIES; //reset the value of the variable
      //msg_pending_ = TRUE;
    }
    return FAIL;
  }
  
  
  //--------------------------------------------------------------------------
  //  SendRREQ.sendDone: If the RREQ transmission is finished, it will release
  //  the RREQ and SEND pendings.
  //--------------------------------------------------------------------------
  event void SendRREQ.sendDone(message_t* p_msg, error_t e) {
    dbg("AODV_DBG", "%s\t AODV: SendRREQ.sendDone()\n", sim_time_string());
    //RREQ SENT!ff
    call Leds.led0Toggle();
    send_pending_ = FALSE;
    rreq_pending_ = FALSE;
  }
  
  
  //--------------------------------------------------------------------------
  //  SendRREP.sendDone: If the RREP transmission is finished, it will release
  //  the RREP and SEND pendings.
  //--------------------------------------------------------------------------
  event void SendRREP.sendDone(message_t* p_msg, error_t e) {
    //dbg("AODV_DBG", "%s\t AODV: SendRREP.sendDone()\n", sim_time_string());
    send_pending_ = FALSE;
    if( call PacketAcknowledgements.wasAcked(p_msg) )
      rrep_pending_ = FALSE;
    else
      rrep_pending_ = TRUE;
  }
  
  
  //--------------------------------------------------------------------------
  //  SendRERR.sendDone: If the RERR transmission is finished, it will release
  //  the RERR and SEND pendings.
  //--------------------------------------------------------------------------
  event void SendRERR.sendDone(message_t* p_msg, error_t e) {
    //dbg("AODV_DBG", "%s\t AODV: SendRERR.sendDone() \n", sim_time_string());
    send_pending_ = FALSE;
    call Leds.led0Toggle();
    call Leds.led1Toggle();
    if( call PacketAcknowledgements.wasAcked(p_msg) )
      rerr_pending_ = FALSE;
    else
      rerr_pending_ = TRUE;
  }
  
  
  //--------------------------------------------------------------------------
  //  ReceiveRREQ.receive: If the destination of the RREQ is me, the node will
  //  send the RREP back to establish the reverse route. Or, the node forwards
  //  the RREQ to the nextt-hop node.
  //--------------------------------------------------------------------------
  event message_t* ReceiveRREQ.receive( message_t* p_msg, 
                                                 void* payload, uint8_t len ) {
    
    bool cached = FALSE;
    bool added  = FALSE;
    bool neighbor = FALSE;
            
    am_addr_t me = call AMPacket.address(); //My address
    am_addr_t src = call AMPacket.source( p_msg ); //Source address
    aodv_rreq_hdr* aodv_hdr      = (aodv_rreq_hdr*)(p_msg->data); //Copy the message to a Struct
    aodv_rreq_hdr* rreq_aodv_hdr = (aodv_rreq_hdr*)(p_rreq_msg_->data);
    aodv_rrep_hdr* rrep_aodv_hdr = (aodv_rrep_hdr*)(p_rrep_msg_->data);
    
    //
    
    
    //dbg("AODV", "%s\t AODV: ReceiveRREQ.receive() src:%d dest: %d \n",
    //                 sim_time_string(), aodv_hdr->src, aodv_hdr->dest);
    printf("*AODV_M* -> Received RREQ: src = %d, dest = %d, from %d\n", aodv_hdr->src, aodv_hdr->dest, src);
    printfflush();         
    //call Leds.led1Toggle();
    if( aodv_hdr->hop > AODV_MAX_HOP ) {
      printf("*AODV_M* -> Received RREQ but Max number of HOPs reached\n"); 
    	printfflush();
    	return p_msg;
    }
    
    /* if the received RREQ is already received one, it will be ignored */
    if( !is_rreq_cached( aodv_hdr ) ) {
      //dbg("AODV_DBG", "%s\t AODV: ReceiveRREQ.receive() already received one\n", 
      //                                              sim_time_string());
      //
      printf("*AODV_M* -> Received RREQ: REPEATED\n"); 
    	printfflush(); //Repeated = same RREQ from different node source
      return p_msg;
    }
    
    /* if the received RREQ come from a weak link, it will be ignored */
    /*
    if (getRSSI(p_msg) < 5){ //value may change. use Threshold
    	printf("*AODV_M* -> Received RREQ: REPEATED\n"); 
    	printfflush(); //Repeated = same RREQ from different node source
      return p_msg;
    }
    */
    
    /* add the route information into the route table */
    //  
    added = add_route_table( aodv_hdr->seq, aodv_hdr->src, src, aodv_hdr->hop );
    
    /*
    if ( aodv_hdr->src != src && aodv_hdr->hop == 1 ){
    //The RREQs came from a neighbor
    	neighbor = add_route_table( aodv_hdr->seq, src, src, 1 );
    	if (neighbor){
    	route_table_[get_route_table_index(src)].precursor = 1;
    	} //Or, modify the function add_route_table
    }
    */
    cached = add_rreq_cache( aodv_hdr->seq, aodv_hdr->dest, aodv_hdr->src, aodv_hdr->hop );
    
    //To check which entries have been added
    //printf("*AODV_M* -> Route_Table: %d Neighbor, %d Added\n", neighbor, added);
    //printf("*AODV_M* -> RREQ_Cache %d Cached\n", cached);
    //printfflush();
    
    /* if the destination of the RREQ is me, the node will send the RREP */
    if( aodv_hdr->dest == me) { // && added (dentro del IF)
      rrep_aodv_hdr->seq  = aodv_hdr->seq;
      rrep_aodv_hdr->dest = aodv_hdr->dest;
      rrep_aodv_hdr->src  = aodv_hdr->src;
      rrep_aodv_hdr->hop  = 1;
      sendRREP( src, FALSE );
      
      return p_msg;
    }
    
    // not for me
    if( !rreq_pending_ && aodv_hdr->src != me && cached ) {
      // forward RREQ
      //call Leds.led1Toggle();
      
      
      rreq_aodv_hdr->seq  = aodv_hdr->seq;
      rreq_aodv_hdr->dest = aodv_hdr->dest;
      rreq_aodv_hdr->src  = aodv_hdr->src;
      rreq_aodv_hdr->hop  = aodv_hdr->hop + 1;
      call RREQTimer.stop();
      call RREQTimer.startOneShot( (call Random.rand16() % 7) * 10 );
    }
    
    return p_msg;
  }
  
  
  //--------------------------------------------------------------------------
  //  ReceiveRREP.receive: If the source address of the RREP is me, it means
  //  the route to the destination is established. Or, the node forwards
  //  the RREP to the next-hop node.
  //----------------msg_retries_ = AODV_MSG_RETRIES;----------------------------------------------------------
  event message_t* ReceiveRREP.receive( message_t* p_msg, 
                                                 void* payload, uint8_t len ) {
    aodv_rrep_hdr* aodv_hdr = (aodv_rrep_hdr*)(p_msg->data);
    aodv_rrep_hdr* rrep_aodv_hdr = (aodv_rrep_hdr*)(p_rrep_msg_->data);
    am_addr_t src = call AMPacket.source(p_msg);
    
    //dbg("AODV", "%s\t AODV: ReceiveRREP.receive() src: %d dest: %d \n", 
    //                         sim_time_string(), aodv_hdr->src, aodv_hdr->dest);
    printf("*AODV_M* -> Received RREP: dest = %d, src = %d, from %d \n", aodv_hdr->src, aodv_hdr->dest, src);
    printfflush();
    
    if( aodv_hdr->src == call AMPacket.address() ) {
      add_route_table( aodv_hdr->seq, aodv_hdr->dest, src, aodv_hdr->hop );
      //call Leds.led1Toggle();
    } else { // not to me
      am_addr_t dest = get_next_hop( aodv_hdr->src );
      if( dest != INVALID_NODE_ID ) {
        // forward RREP
        rrep_aodv_hdr->seq  = aodv_hdr->seq;
        rrep_aodv_hdr->dest = aodv_hdr->dest;
        rrep_aodv_hdr->src  = aodv_hdr->src;
        rrep_aodv_hdr->hop  = aodv_hdr->hop++;
        
        add_route_table( aodv_hdr->seq, aodv_hdr->dest, src, aodv_hdr->hop );
        sendRREP( dest, TRUE );
      }
    }
    return p_msg;
  }
  
  //--------------------------------------------------------------------------
  //  ReceiveRRER.receive: 
  //------------------------------------------------- 
  event message_t* ReceiveRERR.receive( message_t* p_msg, 
                                                 void* payload, uint8_t len ) {
    aodv_rerr_hdr* aodv_hdr = (aodv_rerr_hdr*)(p_msg->data);
    aodv_rerr_hdr* rerr_aodv_hdr = (aodv_rerr_hdr*)(p_rerr_msg_->data);
    am_addr_t me = call AMPacket.address(); //My address
    am_addr_t src = call AMPacket.source( p_msg ); //Source address of the RERR sender

    //dbg("AODV", "%s\t AODV: ReceiveRERR.receive()\n", sim_time_string());
    printf("*AODV_M* -> Received RERR from %d: src = %d, dest = %d\n", src, aodv_hdr->src, aodv_hdr->dest);
    printfflush();
    
    del_route_table( aodv_hdr->dest );
    
    if( aodv_hdr->src == me){
    
    }else { //src
    	printf("*AODV_M* -> RERR not for me, resend to %d\n", aodv_hdr->src);
    	printfflush();
      sendRERR( aodv_hdr->dest, aodv_hdr->src, TRUE );
      }
    
    return p_msg;
  }
  
  
  
  
  
  command error_t AMSend.cancel[am_id_t id](message_t* msg) {
    return call SubSend.cancel(msg);
  }
  
  
  command uint8_t AMSend.maxPayloadLength[am_id_t id]() {
    return call Packet.maxPayloadLength();
  }
  
  
  command void* AMSend.getPayload[am_id_t id](message_t* m, uint8_t len) {
    return call Packet.getPayload(m, 0);
  }
  
  /*
  command void * Receive.getPayload[uint8_t am](message_t *msg, uint8_t *len){
    return call Packet.getPayload(msg, len);
  }
  
  
  command uint8_t Receive.payloadLength[uint8_t am](message_t *msg){
    return call Packet.payloadLength(msg);
  }
  */
  
  /***************** SubSend Events ****************/
  event void SubSend.sendDone(message_t* p_msg, error_t e) {
    aodv_msg_hdr* aodv_hdr = (aodv_msg_hdr*)(p_msg->data);
    bool wasAcked = call PacketAcknowledgements.wasAcked(p_msg);
    am_addr_t dest = call AMPacket.destination(p_aodv_msg_);
    
    //dbg("AODV_DBG", "%s\t AODV: SubSend.sendDone() dest:%d src:%d wasAcked:%d\n",
      //             sim_time_string(), aodv_hdr->dest, aodv_hdr->src, wasAcked);
    
    //bool sameMSG = p_msg == p_aodv_msg_;    
    //printf("AODV: SubSend.sendDone() App:%d dest:%d src:%d wasAcked:%d\n", aodv_hdr->app, aodv_hdr->dest, aodv_hdr->src, wasAcked);
  	//printf("AODV: SubSend.sendDone() msg_pending:%d sameMSG:%d\n p_msg%d p_aodv_msg_%d\n", msg_pending_, sameMSG, p_msg, p_aodv_msg_);
  	//printfflush();
  	
    send_pending_ = FALSE;
    
    if ( msg_pending_ == TRUE && p_msg == p_aodv_msg_ ) { //msg_pending_ == TRUE && 
      if ( wasAcked ) {
        //msg_retries_ = 0;
        msg_pending_ = FALSE;
        printf("*AODV_M* -> Sent AODV msg: dest:%d id:%d Retries left:%u\n", dest, aodv_hdr->app, msg_retries_);
    		printfflush();
      	signal AMSend.sendDone[aodv_hdr->app](p_msg, e);
      } else {
        //msg_retries_--;
        if( msg_retries_ > 0 ) {
          //dbg("AODV", "%s\t AODV: SubSend.sendDone() msg was not acked, resend\n",
            //sim_time_string());
          msg_retries_--;
          //printf("*AODV_M*: Msg not acked, resend. Retries left:%u Pending:%d\n", msg_retries_, msg_pending_);
  				//printfflush();  				                                                   
          call PacketAcknowledgements.requestAck( p_aodv_msg_ );
          call SubSend.send( dest, p_aodv_msg_, 
                                     call Packet.payloadLength(p_aodv_msg_) );
        } else {
          //dbg("AODV", "%s\t AODV: SubSend.sendDone() route may be corrupted\n", 
            //                                                 sim_time_string());
          //del_route_table( dest ); //Borramos entrada ROUTE_TABLE de Destination6
          msg_pending_ = FALSE;
          printf("*AODV_M*: route to %d may be corrupted. Retries left:%u Pending:%d\n", dest, msg_retries_, msg_pending_);
  				printfflush();
  				//msg_pending_ = FALSE;
          //msg_retries_ = AODV_MSG_RETRIES; //reset the value of msg_retries_
          
          if (aodv_hdr->src != TOS_NODE_ID){
          	printf("*AODV_M*: Sending RERR to %d. Retries left:%u Pending:%d\n", aodv_hdr->src, msg_retries_, msg_pending_);
  					printfflush();
          	sendRERR( aodv_hdr->dest, aodv_hdr->src, TRUE );
          } else {
          	printf("*AODV_M* -> NO RERR because I am 1 and NextHOP FAIL\n");
    				printfflush();
    				sendRERR( aodv_hdr->dest, aodv_hdr->src, FALSE ); //No RERR, boolean = FALSE
    				//rerr_pending_ = FALSE;
    				//del_route_table( aodv_hdr->next ); //Borramos entrada ROUTE_TABLE nexthop    			
          }
        }
      }
    } /*else {
   		printf("AODV_M: Sent AODV message: dest: %d id: %d\n", dest, aodv_hdr->app);
    	printfflush();
      signal AMSend.sendDone[aodv_hdr->app](p_msg, e);
    }*/
  }
  
  
  /***************** SubReceive Events ****************/
  event message_t* SubReceive.receive( message_t* p_msg, 
                                                 void* payload, uint8_t len ) {
    uint8_t i;
    aodv_msg_hdr* aodv_hdr = (aodv_msg_hdr*)(p_msg->data);
    
    //dbg("AODV", "%s\t AODV: SubReceive.receive() dest: %d src:%d\n",
      //              sim_time_string(), aodv_hdr->dest, aodv_hdr->src);
    
    if( aodv_hdr->dest == call AMPacket.address() ) {
      //dbg("AODV", "%s\t AODV: SubReceive.receive() deliver to upper layer\n", 
        //                                                     sim_time_string());
      for( i=0;i<len;i++ ) {
        //p_app_msg_->data[i] = aodv_hdr->data[i];
      }
      printf("Receive.receive: type = %d\n msg = %d\n data = %d\n len = %d\n", aodv_hdr->app, p_app_msg_ , p_app_msg_->data, len - AODV_MSG_HEADER_LEN);
    	printfflush();
      p_msg = signal Receive.receive[aodv_hdr->app]( p_app_msg_, p_app_msg_->data, 
                                                     len - AODV_MSG_HEADER_LEN );
    } else {
      am_addr_t nexthop = get_next_hop( aodv_hdr->dest );
      //dbg("AODV", "%s\t AODV: SubReceive.receive() deliver to next hop:%x\n",
        //                                          sim_time_string(), nexthop);
      
      /* If there is a next-hop for the destination of the message, 
         the message will be forwarded to the next-hop.            */
      if (nexthop != INVALID_NODE_ID) {
      printf("Receive.receive: MSG NOT FOR ME, sent to dest = %d\n", nexthop);
    	printfflush();
      forwardMSG( p_msg, nexthop, len );
      } else {
      printf("Receive.receive: MSG NOT FOR ME, nexthop INVALID\n");
    	printfflush();
    	}
    }
    return p_msg;
  }
  
  
  event void AODVTimer.fired() {
    dbg("AODV_DBG2", "%s\t AODV: Timer.fired()\n", sim_time_string());
    if( rreq_pending_ ){
      post resendRREQ();
    }
    
    if( rrep_pending_ ) {
      post resendRREP();
    }
    
    if( rerr_pending_ ) { //at first was rreq_pending_, but was an error 
      post resendRERR();
    }
    
    post update_rreq_cache();
  }
  
  
  event void RREQTimer.fired() {
    //dbg("AODV_DBG", "%s\t AODV: RREQTimer.fired()\n", sim_time_string());
    sendRREQ( 0 , TRUE );
  }
  
  event void RREPTimer.fired() {
    //dbg("AODV_DBG", "%s\t AODV: RREPTimer.fired()\n", sim_time_string());
    sendRREP( 0 , TRUE );
  }
  
  event void RERRTimer.fired() {
    //dbg("AODV_DBG", "%s\t AODV: RREQTimer.fired()\n", sim_time_string());
    sendRERR( 0 , 0, TRUE );
  }
  
  /***************** Defaults ****************/
  default event void AMSend.sendDone[uint8_t id](message_t* msg, error_t err) {
    //call Leds.led2Toggle();
    //To debug errors
    //printf("*AODV_M* -> event AMSend.sendDone\n");
    //printfflush();
    return;
  }
  
  default event message_t* Receive.receive[am_id_t id](message_t* msg, void* payload, uint8_t len) {
    //call Leds.led2Toggle();
    //To debug errors
    //printf("*AODV_M* -> event Receive.receive\n");
    //printfflush();
    return msg;
  }
  
  
//#if AODV_DEBUG  
  void print_route_table(){
    uint8_t i;
    for( i=0; i < AODV_ROUTE_TABLE_SIZE ; i++ ) {
      if(route_table_[i].dest == INVALID_NODE_ID)
        break;
      //dbg("AODV_DBG2", "%s\t AODV: ROUTE_TABLE i: %d: dest: %d next: %d seq:%d hop: %d \n", 
        //   sim_time_string(), i, route_table_[i].dest, route_table_[i].next, 
          //       route_table_[i].seq, route_table_[i].hop );
      printf("***AODV: ROUTE_TABLE i: %d: dest: %d next: %d seq: %d hop: %d \n", 
           		i, route_table_[i].dest, route_table_[i].next, 
           		route_table_[i].seq, route_table_[i].hop);
      printfflush();     		 
    }
  }
  
  
  void print_rreq_cache() {
    uint8_t i;
    for( i=0 ; i < AODV_RREQ_CACHE_SIZE ; i++ ) {
      if(rreq_cache_[i].dest == INVALID_NODE_ID )
        break;
      //dbg("AODV_DBG2", "%s\t AODV: RREQ_CACHE i: %d: dest: %d src: %d seq:%d hop: %d \n", 
        //   sim_time_string(), i, rreq_cache_[i].dest, rreq_cache_[i].src, 
        	//		rreq_cache_[i].seq, rreq_cache_[i].hop );
    printf("***AODV: RREQ_CACHE i: %d: dest: %d src: %d seq: %d hop: %d \n", 
           		i, rreq_cache_[i].dest, rreq_cache_[i].src, rreq_cache_[i].seq, 
           		rreq_cache_[i].hop);
    printfflush();
    
    }
  }
//#endif

//**********************
// Definition of getRssi: return the RSSI of the msg  
//**********************

//CHIPS CC2420 and CC1000

  #ifdef __CC2420_H__  
  uint16_t getRssi(message_t *msg){
    return (uint16_t) call CC2420Packet.getRssi(msg);
  }
#elif defined(CC1K_RADIO_MSG_H)
    uint16_t getRssi(message_t *msg){
    cc1000_metadata_t *md =(cc1000_metadata_t*) msg->metadata;
    return md->strength_or_preamble;
  }
  
  //For CHIP RF230
#elif defined(PLATFORM_IRIS) //|| defined(PLATFORM_UCMINI)

//**********************
// Definition of getRssi: return the RSSI of the msg  
//**********************
  uint16_t getRssi(message_t *msg){
    if(call PacketRSSI.isSet(msg))
      return (uint16_t) call PacketRSSI.get(msg);
    else
      return 0x1FFF;
  }
  
//**********************
// Definition of getLQI: return the LQI of the msg 
//**********************  
  uint16_t getLQI(message_t *msg){
    if(call PacketLinkQuality.isSet(msg))
      // if(LinkPacketMetadata.highChannelQuality(msg){
      //	GOOD CHANNEL	
      //}		
      return (uint8_t) call PacketLinkQuality.get(msg);
    else
      return 0x11;
  }
//**********************
// Definition of getTxPower: useless, only usefull to set the power of the msg 
//**********************  
  uint16_t getTxPower(message_t *msg){
    if(call PacketTransmitPower.isSet(msg))
      // if(LinkPacketMetadata.highChannelQuality(msg){ //Return TRUE if LQI>220
      //	GOOD CHANNEL	
      //}		
      return (uint16_t) call PacketTransmitPower.get(msg);
    else
      return 0x1FFF;
  }
/*
* For othet Chip
*

#elif defined(TDA5250_MESSAGE_H)
   uint16_t getRssi(message_t *msg){
       return call Tda5250Packet.getSnr(msg);
   }
   */
#else
  #error Radio chip not supported! This demo currently works only \
         for motes with CC1000, CC2420, RF230, RFA1 or TDA5250 radios.  
#endif

}


/*
 * Example: 
 *
#ifdef PLATFORM_IRIS      
      RssiValue = getRssi(msg);
      LQIvalue = getLQI(msg);
      TxPower = getTxPower(msg);
      //Print it thorough Serial Port
      printf("RECEIVED msg: Counter = %d, RSSI = %u, LQI = %u, TxPower = %u\n", 
      				pmsg*->counter, RssiValue, LQIvalue, TxPower);
  		printfflush();
#endif
*/

