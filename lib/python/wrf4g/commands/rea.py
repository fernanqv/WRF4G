"""
Manage WRF4G realizations. 
    
Usage: 
     wrf4g rea <name> submit [ --dbg ] [ --dry-run ] [ --rerun ] [ <first_ch> [ <last_ch> ] ]
     wrf4g rea <name> status [ --dbg ] [ --delay=<seconds> ]
     wrf4g rea <name> log    [ --dbg ] <chunk_id> [ --dir=<directory> ]
     wrf4g rea <name> cancel [ --dbg ] [ --dry-run ] [ --hard ]
   
Options:
    --dbg                 Debug mode.
    -n --dry-run          Dry run.
    --rerun               Force to run although the realization has finished.
    --delay=<seconds>     Refresh experiment information every delay seconds.    
    -d --dir=<directory>  Directory to unpack log files [default: ./].
    --hard                Remove jobs from without synchronizing.
  
Commands:
    submit                Submit the realization.       
    status                Check the status of a realization showing computing resources, 
                          job identifier and exit codes (SEE EXIT CODES).
    log                   Get log files from a chunk. 
    cancel                Cancel the realization by killing its jobs.

EXIT CODES
    1 : Error creating directory to simulate
    2 : Error creating log directory        
    3 : Error copying apps            
    4 : Error app type does not exist            
    5 : Error executing source script       
    6 : Job already executed  
    7 : Error copying restart files        
    8 : There is a mismatch in the restart date   
    9 : Error copying namelist.wps    
    10: Error downloading WPS files    
    11: Error copying boundaries           
    12: Error modifying namelist
    13: Error executing PREPROCESSOR
    14: Error linking GRIB files     
    15: Error executing UNGRIB
    16: Error executing METGRID       
    17: Error executing REAL
    18: Error uploadinf WPS files      
    19: Error executing WRF
    20: Error executing POSTPROCESSOR 
    21: Error copying output file
"""
__version__  = '2.0.0'
__author__   = 'Carlos Blanco'
__revision__ = "$Id$"

import logging
import sys
import time
from sqlalchemy.orm.exc   import NoResultFound
from sqlalchemy.exc       import OperationalError
from wrf4g.utils.command  import cls
from wrf4g.db             import get_session
from wrf4g.core           import Realization

def run( arg ) :
    logging.basicConfig( format = '%(message)s',
                         level  = logging.DEBUG if arg[ '--dbg' ] else logging.INFO,
                         stream = sys.stdout )
    # create a session to connect with the database
    session = get_session()
    try :
        try : 
            rea = session.query( Realization ).\
                    filter( Realization.name   == arg[ '<name>' ], 
                            Realization.exp_id != None ).one()
            rea.dryrun = arg[ '--dry-run' ]
        except NoResultFound :
            raise Exception( "'%s' realization does not exist" % arg[ '<name>' ] )
        else :
            if arg[ 'submit' ] :
                rea.run( first_chunk_run = arg[ '<first_ch>' ], 
                         last_chunk_run  = arg[ '<last_ch>' ] , 
                         rerun           = arg[ '--rerun' ] )
            elif arg[ 'status' ] :
                if not arg[ '--delay' ] :
                    rea.status_header( )
                    rea.get_status( )
                else :
                    try:
                        while True :
                            cls()
                            rea.status_header()
                            rea.get_status( )
                            time.sleep( int( arg[ '--delay' ] ) )
                    except KeyboardInterrupt :
                        pass
            elif arg[ 'log' ] :
                rea.get_log( arg[ '<chunk_id>' ], arg[ '--dir' ] )
            else :
                rea.cancel( arg[ '--hard' ] )
            if arg[ '--dry-run' ] :
                session.rollback()
            else :
                session.commit()
    except OperationalError, err :
        logging.error( err.message )
    except Exception , err :
        session.rollback()
        logging.error( str( err ) )
    finally:
        session.close()
