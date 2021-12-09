#
# CMPUT 229 Public Materials License
# Version 1.0
#
# Copyright 2020 University of Alberta
# Copyright 2021 Emily Vandermeer
#
# This software is distributed to students in the course
# CMPUT 229 - Computer Organization and Architecture I at the University of
# Alberta, Canada.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the disclaimer below in the documentation
#    and/or other materials provided with the distribution.
#
# 2. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from this
#    software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
#-------------------------------
# Lab_Typing_Game Lab
#
# Author: Emily Vandermeer
# Date: June 11, 2021
#
# This program initializes four global variables to be used by the 
# student-written function: random. Then this program reads in the strings from a given file and places them into memory. Then this program jumps to the student 
# code under the label "typing" which is responsible for executing a typing game
#-------------------------------

.data
iTrapData:	.space	256	# allocate space for the interrupt trap data

        .align  2        
XiVar:  	.word   15 	# starting seed of the LCG 
aVar:   	.word   14	# constant multiplier of the LCG 
cVar:   	.word   3   	# constant increment of the LCG 
mVar:   	.word   25 	# the modulus of the LCG should be kept as 25

phrases:    	.space 4000 	# This is space for the phrases array that will be read into the program 
array:      	.space 104 	# This is the space set aside for the array of pointers 

noFileStr: 			# This is for when the file does not open or can not be found
    .asciz "Couldn't open specified file.\n"   

.text 
main:
	lw      a0, 0(a1)	        # Put the filename pointer into a0
    	li      a1, 0		        # Read Only
    	li      a7, 1024		# Open File
    	ecall
    	bltz	a0, main_err	    	# Negative means open failed	
    	la      a1, phrases	        # write into my binary space
   	li      a2, 4000       		# read a file of at max 2kb
   	li      a7, 63		        # Read File System call
	ecall
	
	la      t0, phrases		# Load the pointer to the phrase memory area
    	add     t0, t0, a0	        # Point to end of the phrases 
    	la 	t1, array		# Load the address of the first part of the array into t1
    	li  	t3, 10			

    	
arrayloop:
	# Place the first value then loop through the code until it reaches the hexadecimal character 10, once it does save the next value into array continue until it reaches t0 
	sw 	a1, 0(t1) 		# Save the phrase into a1 
	addi 	t1, t1 4 		# Move the value of t1 up by 4
loadsection:
	lb 	t2, 0(a1) 		# Load the byte from the phrase memory section into t2
	beq 	a1, t0, main_typing 	# Once you get to the end of the array, exit this 
	addi 	a1, a1, 1 		# Add one to the value of a1 to increase to the next byte
	beq 	t2, t3, arrayloop 	
	beqz 	zero, loadsection 	# Loop through the loading of the bytes
	
	
	
	
main_typing:
	# Setup the uscratch control status register
	la	t0, iTrapData		# t0 <- Addr[iTrapData]
	csrw	t0, 0x040		# CSR #64 (uscratch) <- Addr[iTrapData]
	la 	a0, array		# A pointer to the first pointer to the first phrase  in the array of pointers 
	jal 	ra, typing	
	
	
	beqz 	zero, main_done
    	




main_err:
    	la      a0, noFileStr
    	li      a7, 4
    	ecall




main_done:

	li      a7, 10      		# ecall 10 exits the program with code 0
	ecall
