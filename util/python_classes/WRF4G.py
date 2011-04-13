#!/usr/bin/python

from sys import stderr,exit, path
import sys
import inspect
path.append('/home/valva/WRF4G/util/python_classes')
import vdb
from optparse import OptionParser

def pairs2dict(pairs):
    d={}
    for p in pairs.split(','):
        s=p.split('=')
        d[s[0]]=s[1]
    return d

def list2fields(arr):
    fields=''
    for i in arr:
       fields=",%s,%s" %(fields,i)
       fields=fields[2:]
    return fields

def instantiate(fqcn):
    """Given foo.bar.Zoo.ZapClass, return an instance of ZapClass."""
    paths = fqcn.split('.')
    modulename = '.'.join(paths[:-1])
    classname = paths[-1]
    __import__(modulename)
    return getattr(sys.modules[modulename], classname)()

def get_classes():
    clsmembers = inspect.getmembers(sys.modules[__name__], inspect.isclass)
    cl=[]   
    for tup in clsmembers:
        cl.append(tup[0])
    return cl 

class Component:
    """  Component CLASS
    """

    def __init__(self,data='',verbose='no',reconfigure='no'):
        self.verbose=verbose
        self.reconfigure=reconfigure
        self.element=self.__class__.__name__
        self.data=data
        self.allfields=['','','','']        
        #for field in data.keys():            
        #    setattr(self,field,data[field])
            
    def get_all_fields(self):
        dbc=vdb.vdb()
        salida=dbc.describe(self.element)
        return salida
    
    def get_id(self,fields):
        """    
        Query database to check if the experiment exists.
        fields is a list with the fields to check in the query.
        Returns:
        -1 --> not exists
        exp.id --> exists with the same parameters 
        """
        wheresta=''
        dbc=vdb.vdb()
        for field in fields:
            wheresta="%s AND %s='%s'" %(wheresta,field,self.data[field])
        wheresta=wheresta[4:]
        
        idp=dbc.select(self.element,'id',wheresta,verbose=self.verbose)
        id = vdb.list_query().one_field(idp)
        if id !='': return id
        else: return -1
            
    def loadfromDB(self,fields):
     """    
     Given an array with the fields to check in the query, this function loads into 
     self.data the Wrf4gElement values.
     Returns:
     0-->OK
     1-->ERROR
     """

     wheresta=''
     dbc=vdb.vdb()
     for field in fields:
         wheresta="%s AND %s='%s'" %(wheresta,field,self.data[field])
     wheresta=wheresta[4:]     
     #dic=dbc.select(self.element,list2fields(fields), wheresta, verbose=1 )
     dic=dbc.select(self.element,WRF4G.utils.list2fields(fields),wheresta, verbose=1 )
     self.__init__(dic[0])
     print self.sdate
     if id>0: return id
     else: return -1
      
    def create(self):
        """
        Create experiment
        Returns id:
        id > 0 --> Creation Worked.
        -1--> Creation Failed
        """
        dbc=vdb.vdb()
        id=dbc.insert(self.element,self.data,verbose=self.verbose)
        if id>0: return id
        else: return -1
        
    def update(self):
        """
        Update experiment
        Returns id:
        id >0 --> Creation Worked.
        -1--> Creation Failed
        """
        dbc=vdb.vdb()
        
        ddata={}
        for field in self.get_reconfigurable_fields():
            ddata[field]=self.data[field]
        
        condition='id=%s'%self.data['id']
        id=dbc.update(self.element,ddata,condition,verbose=self.verbose)
        if id>0: return id
        else: return -1   
     
    def prepare(self):
        """
        Checks if experiment exists in database. If experiment exists, 
        check if it is the same configuration that the one found in 
        the database.
        If the experiment exists and some parameters do not match the ones
        found in database check if its a reconfigure run. 
        Returns
        0--> Database do not have to be changed.
        1--> Change DataBase
        2--> Error. Experiment configuration not suitable with database
        """       
        change=0
        id=self.get_id(self.get_distinct_fields())
        if id != -1: self.data['id']=id
        # Experiment exists in database
        if id > 0:
            id=self.get_id(self.get_configuration_fields())
            # Experiment is different that the one found in the database
            if id == -1:
                if self.reconfigure == False:
                    stderr.write("""Error: %s with the same name and different
                    configuation already exists\n""" %self.element) 
                    change=-1
                else: 
                    id=self.get_id(self.get__no_reconfigurable_fields())
                    if id == -1:
                        stderr.write("""Error: %s with the same name and different
                        configuation already exists\n"""%self.element) 
                        exit(9)
                    else: 
                        self.update()
                        change=1
            else:
                if self.verbose: stderr.write('%s already exists.\n'%self.element)
        else:
            if self.verbose: stderr.write('Creating %s\n'%self.element)
            self.create()
            change=1
            
        return change
       
    
      
class Experiment(Component):
    
    """  Experiment CLASS
    """
    def get__no_reconfigurable_fields(self):
        return ['id','cont','basepath']
    
    def get_configuration_fields(self):
        return ['id','sdate','edate','basepath','cont']
    
    def get_distinct_fields(self):
        return['name']
        
    def get_reconfigurable_fields(self):
        return['sdate','edate']
    
   
      
class Realization(Component):
    """ Realization CLASS
    """
    pass    
 
if __name__ == "__main__":
    usage="""%prog [OPTIONS] exp_values function fvalues 
             Example: %prog 
    """

    
    parser = OptionParser(usage,version="%prog 1.0")
    parser.add_option("-v", "--verbose",action="store_true", dest="verbose", default=False,help="Verbose mode. Explain what is being done")
    parser.add_option("-r", "--reconfigure",action="store_true", dest="reconfigure", default=False,help="Reconfigure element in WRF4G")
    (options, args) = parser.parse_args()
    
    if len(args) < 2:
        parser.error("Incorrect number of arguments")
        exit(1)
        
    class_name=args[0]
    function=args[1]

    data=''
    if len(args) > 2:   data=pairs2dict(args[2])         
    inst="%s(data=%s,verbose=options.verbose,reconfigure=options.reconfigure)"%(class_name,data)
    comp=eval(inst)
    if len(args) > 3:     
        fvalues=args[3:]
        output=getattr(comp,function)(fvalues)
    else:                  
        output=getattr(comp,function)()
    print output




   
