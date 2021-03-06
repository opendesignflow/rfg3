package provide odfi::rfg::stdlib  3.0.0
package require odfi::rfg 3.0.0
package require odfi::rfg::generator::h2dl 3.0.0
package require odfi::richstream 3.0.0
package require odfi::language::nx 1.0.0

#set width 64
#puts "power of 2 for $width : [expr 2**int(ceil(log($width)/log(2)))] -> [expr 2**6] "
#exit 0


namespace eval odfi::rfg::stdlib {

    variable stdlibLocation [file dirname [file normalize [info script]]]

    ::odfi::language::Language default {

        set targetPrefix stdlib

        :fifo : ::odfi::rfg::Register name {
            +exportTo   ::odfi::rfg::Group $targetPrefix
            +mixin      ::odfi::rfg::generator::h2dl::H2DLSupport
            +var        width 8
            +var        fifoName ""

            ## After building done, maybe add a Register for control and stuff
            +builder {
                :attribute odfi::rfg::hardware rw wo
                :attribute odfi::rfg::software rw ro
                set :fifoName ${:name}
            }

            +method setHWRead args {
                :attribute odfi::rfg::hardware rw ro
                :attribute odfi::rfg::software rw wo
            }
            
            
            +method useXilinxSimpleFifo  args {
                odfi::log::info "Generating FIFO as Xilinx XCO Module"

                ## Check
                odfi::log::info "The FIFO width should be a power of 2"
                odfi::log::info "Actual width ${:width}"

                ## Get number of bits required for width, and matching power of 2 value
                set fifoWidth [expr 2**int(ceil(log(${:width})/log(2)))]
                odfi::log::info "FIFO width ${fifoWidth}"
                
                if {${:width}!=${fifoWidth}} {
                    odfi::log::info "Using asymetric FIFO"
                }

                ## Create XCO File for the output 
                ##########
                #set xcoFileContent [odfi::richstream::template::fileToString ${::odfi::rfg::stdlib::stdlibLocation}/fifo/rfg_fifo_xilinx_xco.template]
               # :attribute ::odfi::h2dl sourceFile [list ${:fifoName}.xco $xcoFileContent]


                ## Create Module Instance
                ################
                set fifoModule [::odfi::h2dl::module ${:fifoName} {
                    :attribute ::odfi::h2dl blackbox true
                    :input rst {
                        :attribute ::odfi::rfg::h2dl reset true
                    }
                    :input wr_clk
                    :input rd_clk {
                        :attribute ::odfi::rfg::h2dl clock true
                    }
                    :input d_in {
                        :width set ${fifoWidth}
                    }
                    :input wr_en 
                    :input rd_en {
                        :attribute ::odfi::rfg::h2dl read_enable true
                    }
                    :output d_out {
                        :width set 8
                        :attribute ::odfi::rfg::h2dl data_out true
                    }
                    :output full 
                    :output almost_full
                    :output empty
                    :output almost_empty
                    

                }]

                ## Add a Instance of this module
                set instance [:addChild [$fifoModule createInstance ${:name}]]
                #$fifoModule

            }
            

            ## H2DL  Producer 
            +method h2dl:produce args {

                
                set childInstance [:shade odfi::h2dl::Module child 0]
                if {$childInstance!=""} {
                    return $childInstance
                }
                error "Producing H2DL on Stdlib FIFO has no default implementation"

            }

        }

    }


}


## Xilinx Stuff
##########################

odfi::language::nx::new ::odfi::rfg::xilinx {

    :fifo : ::odfi::rfg::Register name {
        +exportTo   ::odfi::rfg::Group xilinx
        +mixin      ::odfi::rfg::generator::h2dl::H2DLSupport
        
        +var softReset false
        
        +builder {
            :attribute odfi::rfg::hardware rw w
            :attribute odfi::rfg::software rw r
        }
        
        +method useSoftReset args {
            set :softReset true
        }
        
        +method setHWRead args {
            :attribute odfi::rfg::hardware rw r
            :attribute odfi::rfg::software rw w
        }
        
        ## XILINX XCO
        ##########################
        ## Use generator 
        +method generateXCOFIFO  args {

            odfi::log::info "Generating FIFO as Xilinx XCO Module"



            ## Check
            odfi::log::info "The FIFO width should be a power of 2"
            odfi::log::info "Actual width [:getWidth]"

            ## Get number of bits required for width, and matching power of 2 value
            set fifoWidth [expr 2**int(ceil(log([:getWidth])/log(2)))]
            odfi::log::info "FIFO width ${fifoWidth}"

            ## Get Depth 
            if {![:hasAttribute hw depth]} {
                error "Cannot generate Xilinx FIFO if no hw.depth attribute is set in: [odfi::common::describeCallerLocation]"
            }
            set depth [:attribute hw depth]

            ## Reset 
            set reset_type "Asynchronous_Reset"
            if {[:attributeMatch hw reset synchronous]} {
                set reset_type "Synchronous_Reset"
            }

            ## Device
            if {[:hasAttribute xilinx device]} {
                set xDevice     [split [:attribute xilinx device] :]
                set xPackage    [lindex $xDevice 2]
                set xFamily     [lindex $xDevice 0]
                set xDevice     [lindex $xDevice 1]
            } else {
                error "Please provide an DEVICE:PACKAGE attribute under :attribute xilinx device"
            }


            ## Create XCO File for the output 
            ##########
            set xcoFileContent [odfi::richstream::template::fileToString ${::odfi::rfg::stdlib::stdlibLocation}/fifo/rfg_fifo_xilinx_xco.template]
            


            ## Create Module Instance
            ################
            set fifoModule [::odfi::h2dl::module [:getHierarchyName] {
                :attribute ::odfi::h2dl blackbox true
                :input rst {
                    :attribute ::odfi::rfg::h2dl reset posedge
                   
                }
                :input clk {
                    :attribute ::odfi::rfg::h2dl clock true
                }
                
                
                :input din {
                    :width set $fifoWidth
                    :attribute ::odfi::rfg::h2dl data_in true
                }
                :input wr_en {
                    :attribute ::odfi::rfg::h2dl write_enable true   
                }
                :input rd_en {
                    :attribute ::odfi::rfg::h2dl read_enable true

                }
                :output dout {
                    :width set $fifoWidth
                    :attribute ::odfi::rfg::h2dl data_out true
                }
                :output full 
                :output almost_full
                :output empty
                :output almost_empty
                

            }]

            ## Add a Instance of this module
            $fifoModule attributeAppend ::odfi::verilog companions [list [list [:getHierarchyName].xco $xcoFileContent]]
            :addChild $fifoModule
            #set instance [:addChild [$fifoModule createInstance ${:name}]]
            #$fifoModule

        }



        ## XILINX XCI Format support
        ###########
        +method useXilinxXCIFifo xciFile {
        
            set xciFile [::odfi::files::fileRelativeToCaller $xciFile]
        
            ## Checks
            #############
            if {![file exists $xciFile]} {
                odfi::log::error "Xilinx FIFO XCI $xciFile does not exist"
            }
            
            ## Create Module based on file 
            ############
            set fileContent [odfi::files::readFileContent $xciFile]
        
            puts "Done XCI Reading"
            
            ## get Name
            regexp {<spirit:instanceName>([\w_-]+)<\/spirit:instanceName>} $fileContent -> instanceName
            
            ## Prepare Module based on name 
            set module [::odfi::h2dl::module $instanceName]
            $module attribute ::odfi::h2dl blackbox true
            :addChild $module
            
            ## get depth
            regexp {<spirit:configurableElementValue spirit:referenceId="PARAM_VALUE.Output_Depth">([0-9]+)<\/spirit:configurableElementValue>} $fileContent -> depth
            :attribute ::odfi::rfg::stdlib::fifo depth $depth
            
            ## First Word through 
            set options [:spiritGetElementValue $fileContent PARAM_VALUE.Performance_Options]
            if {[string match *First_Word_Fall_Through* $options]} {
                :attribute ::odfi::rfg::stdlib::fifo fallthrough true
            }
            
            ## IOs: Find data and address length
            #######################
            set fifoReg [current object]
            
            set hwRead  [:attributeMatch odfi::rfg::hardware rw r]
            set hwWrite [:attributeMatch odfi::rfg::hardware rw w]
            
            ## One or two clocks?
            set independentClocks false 
            if {[:spiritGetElementValue  $fileContent PARAM_VALUE.Fifo_Implementation]=="Independent_Clocks_Block_RAM"} {
                set independentClocks true
            } else {
                $module input clk {
                   :attribute ::odfi::rfg::h2dl clock true                  
                }
            }
            
            ## Reset?
            if {[:spiritGetElementValue  $fileContent PARAM_VALUE.Reset_Pin]} {
                $module input rst {
                    :attribute ::odfi::rfg::h2dl reset posedge  
                    
                    if {${:softReset}} {
                        :attribute ::odfi::rfg::h2dl soft_reset true
                    }   
                         
                }
            }
            
            ## Input or Output of data
            ####
            
            $module input din {
                :width set [$fifoReg spiritGetElementValue $fileContent PARAM_VALUE.Input_Data_Width]
                if {$hwRead} {
                    :attribute ::odfi::rfg::h2dl data_in true                 
                }
            }
            $module input wr_en {
                if {$hwRead} {
                    :attribute ::odfi::rfg::h2dl write_enable true   
                }        
            }
            if {$independentClocks} {
                $module input wr_clk {
                  if {$hwRead} {
                      :attribute ::odfi::rfg::h2dl clock true    
                    }
                }
            }
            
            ## output 
            $module output dout {
                :width set [$fifoReg spiritGetElementValue $fileContent PARAM_VALUE.Output_Data_Width] 
                 if {$hwWrite} {
                      :attribute ::odfi::rfg::h2dl data_out true                 
                 }  
            }
            $module input rd_en {
                if {$hwWrite} {
                    :attribute ::odfi::rfg::h2dl read_enable true   
                }
                  
            }
            if {$independentClocks} {
                $module input rd_clk {
                  if {$hwWrite} {
                    :attribute ::odfi::rfg::h2dl clock true    
                  }
                }
            }
            
            ## Full/empty
            $module output full {
            }
            $module output empty {
            }
            
            ## Almost empty
            if {[:spiritGetElementValue  $fileContent PARAM_VALUE.Almost_Empty_Flag]} {
                $module output almost_empty {
                }
            }
            
            ## Almost full
            if {[:spiritGetElementValue  $fileContent PARAM_VALUE.Almost_Full_Flag]} {
                $module output almost_full {
                }
            }
            #puts "AFULL: $almostFull"
            
            
        }
        
        +method spiritGetElementValue {content name} {
            regexp "<spirit:configurableElementValue spirit:referenceId=\"$name\">(\[\\w_-\]+)<\\/spirit:configurableElementValue>" $content -> result
            
            return $result
                        
        }
        
        ## Add Status Register
        +method addStatusRegister args {
            
            #:onBuildDone {
                
                puts "*** ADDING SR"
                
                ## Get FIFO Module
                set fifoModule [:shade ::odfi::h2dl::Module firstChild]
                if {$fifoModule==""} {
                    error "Cannot use addStatusRegister if FIFO module has not been prepared"
                }
                
                ## Add Status Register to parent container
                set parent [:parent]
                set statusRegister [$parent register [:name get]_status {
                    :attribute ::odfi::rfg::hardware hide true
                }]
                
                ## Add Fields with features
                set registerAssignList {}
                set searchList {full empty almost_full almost_empty}
                foreach search $searchList {
                    set io [$fifoModule shade ::odfi::h2dl::IO findChildByProperty name $search]
                    if {$io!=""} {
                        $statusRegister field $search
                        lappend registerAssignList [:getHierarchyName]_$search
                    }
                }
               
               
                
                
                ## Add Produce method to replace write section
                $statusRegister object mixins add ::odfi::rfg::generator::h2dl::H2DLSupport
                $statusRegister object variable registerAssignList $registerAssignList
                $statusRegister object method h2dl:produce rfgModule {
                    next
                    set targetReg [current object]
                    set targetH2LDReg [$rfgModule register [$targetReg getHierarchyName] {
                        :width set [$targetReg getWidth]
                    }]
                    set section [::odfi::h2dl::section::logicsection writeSection {
                        :attribute ::odfi::rfg writeSection true
                        
                        :posedge $clk {
                            :if {! $res_n} {
                                $targetH2LDReg <= 0
                            } 
                            :else {
                                
                                $targetH2LDReg <= "[join [lreverse ${:registerAssignList}] ,]"
                            }
                        }
                        
                    }]
                    
                    return $section
                }
                
                
           # }
        
        }
        
        ## Add Status Register
        +method addPositionRegister args {
            
            #:onBuildDone {
                
                puts "*** ADDING PositionSR"
                
                ## Get FIFO Module
                set fifoModule [:shade ::odfi::h2dl::Module firstChild]
                if {$fifoModule==""} {
                    error "Cannot use addStatusRegister if FIFO module has not been prepared"
                }
                
                ## Get DIN and DOUT
                ## If not assymetric; issue a warning and don't produce
                set din [$fifoModule shade ::odfi::h2dl::IO findChildByProperty name din]
                set dout [$fifoModule shade ::odfi::h2dl::IO findChildByProperty name dout]
                
                if {[$din width get] == [$dout width get]} {
                    ::odfi::log::warning "FIFO Position register is useless if din and dout have the same size"
                } else {
                    
                    ## Add Position Register to parent container
                    set parent [:parent]
                    set positionRegister [$parent register [:name get]_status {
                        :attribute ::odfi::rfg::hardware hide true
                    }]
                    
                    ## Add So many bits as din/dout difference
                    set bitsCount [expr [$din width get] / [$dout width get]]
                    ::repeat $bitsCount {
                        $positionRegister field p$i
                    }
                    
                    ## Add Produce method to replace write section
                    set fifoReg [current object]
                    $positionRegister object mixins add ::odfi::rfg::generator::h2dl::H2DLSupport
                    $positionRegister object variable relatedFifoReg [current object]
                    $positionRegister object method h2dl:produce rfgModule {
                        next
                        set targetReg [current object]
                        set targetH2LDReg [$rfgModule register [$targetReg getHierarchyName] {
                            :width set [$targetReg getWidth]
                        }]
                        set section [::odfi::h2dl::section::logicsection writeSection {
                            :attribute ::odfi::rfg writeSection true
                            
                            :posedge $clk {
                                :if {! $res_n} {
                                    $targetH2LDReg <= 1
                                } 
                                :else {
                                    
                                    :if "[${:relatedFifoReg} getHierarchyName]_read_enable" {
                                        $targetH2LDReg <= "( $targetH2LDReg << 1) , ( $targetH2LDReg @ [expr [$targetH2LDReg width get] - 1 ] ) "
                                    }
                                    
                                }
                            }
                            
                        }]
                        
                        return $section
                    }
                    
                
                }
                
                
                
                
                
           # }
        
        }
        
        ## H2DL  Producer 
        +method h2dl:produce args {

            
            set childInstance [:shade odfi::h2dl::Module child 0]
            if {$childInstance!=""} {
                return $childInstance
            }
            error "Producing H2DL on Stdlib FIFO has no default implementation"

        }
        
        
    }

}
