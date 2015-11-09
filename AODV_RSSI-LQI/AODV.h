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


typedef nx_struct {
  nx_uint8_t    seq;
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
  nx_uint8_t    hop;
  nx_uint8_t    Maxhop;
  nx_uint8_t    numRetries;
  nx_uint8_t		qual;
} aodv_rreq_hdr;


typedef nx_struct {
  nx_uint8_t    seq;
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
  nx_uint8_t    hop;
  nx_uint8_t    Maxhop;
  nx_uint8_t    numRetries;
  nx_uint8_t		qual;
  nx_bool				llRepair; //Local Link Repair
} aodv_rrep_hdr;


typedef nx_struct {
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
  nx_uint8_t    seq; //Source of the original message, destination of RERR
  nx_uint8_t    hop;
  nx_uint8_t    numRetries;
  nx_bool				llRepair; //Local Link Repair
} aodv_rerr_hdr;


typedef nx_struct {
  nx_am_addr_t  dest;
  nx_am_addr_t  src;
  nx_uint8_t    app;
  nx_uint8_t    data[4]; //former data[1]
  nx_uint8_t		qual;
} aodv_msg_hdr;


typedef struct {
  uint8_t    seq;
  am_addr_t  dest;
  am_addr_t  next;
  uint8_t    hop;
  uint8_t    ttl;
  uint8_t		Rquality;
  uint8_t  precursor;
  bool    	valid;
} AODV_ROUTE_TABLE;


typedef struct {
  uint8_t    seq;
  am_addr_t  dest;
  am_addr_t  src;
  uint8_t    hop;
  uint8_t		Rqual;
  uint8_t    ttl;
} AODV_RREQ_CACHE;


#define AODV_RREQ_HEADER_LEN  sizeof(aodv_rreq_hdr)
#define AODV_RREP_HEADER_LEN  sizeof(aodv_rrep_hdr)
#define AODV_RERR_HEADER_LEN  sizeof(aodv_rerr_hdr)
#define AODV_MSG_HEADER_LEN   sizeof(aodv_msg_hdr)

//Better to set the Retries = 5

#define AODV_RREQ_RETRIES     3 
#define AODV_RREP_RETRIES     3
#define AODV_RERR_RETRIES     3
#define AODV_MSG_RETRIES      3
#define AODV_MAX_HOP          10

#define AODV_DEFAULT_PERIOD   100
#define AODV_RREQ_CACHE_TTL   5
#define AODV_ROUTE_TABLE_TTL  100

#define AODV_RREQ_CACHE_SIZE  10
#define AODV_ROUTE_TABLE_SIZE 10

#define INVALID_NODE_ID       0xFFFF
#define INVALID_INDEX         0xFF

enum {
	RSSI_THRESHOLD = 5,
	LQI_THRESHOLD = 230,
	AODV_LINKREPAIR_PERIOD = 200,
};

