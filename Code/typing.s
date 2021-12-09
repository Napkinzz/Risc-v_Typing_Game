#
# CMPUT 229 Public Materials License
# Version 1.0
#
# Copyright 2020 University of Alberta
# Copyright 2021 Emily Vandermeer
# TODO: claim your copyright
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
# Author: Lukas Waschuk	
# Date: 2021-10-30
# TA: unknown
#
#-------------------------------
.include "common.s"

.data
.align 17
TIMECMP:		.word 0xFFFF0020
TIME:			.word 0xFFFF0018
DISPLAY_DATA:		.word 0xFFFF000C
DISPLAY_CONTROL:	.word 0xFFFF0008
KEYBOARD_DATA:		.word 0xFFFF0004
KEYBOARD_CONTROL:	.word 0xFFFF0000	
TIMER:			.word 0x000003E7	# set after user selects difficulty 
TIMER_STRING:		.word 0x00000000	# string rep of timer 
NEXT_STAGE:		.word 0x00000001	# flag for if the stage is complete
DIFFICULTY_CHOSEN:	.word 0x00000001	# flag for if the difficulty has been chosen
BONUS_TIME:		.word 0x00000000	# set after user chooses difficulty
STAR_COL:		.word 0x00000000	# location of the * to be printed 
CURRENT_STRING:		.word 0x00000000	# current string we are comparing to 
POINTS:			.word 0x00000000	# points counter 
POINTS_STRING:		.word 0x00000000	# string rep of points 
TIMER_FLAG:		.word 0x00000001	# flag for timer int happened 
KEYBOARD_FLAG:		.word 0x00000001	# flag for keyboard int happened 

# taken from displayDemo.s 
INTERRUPT_ERROR:	.asciz "Error: Unhandled interrupt with exception code: "
INSTRUCTION_ERROR:	.asciz "\n   Originating from the instruction at address: "
# my strings 
welcomeMessage:		.asciz "Please enter 1 2 3 to choose the level and start the game: "
space:			.asciz "  " 
gameOver:		.asciz "GAME OVER! "
clear: 			.asciz "                                                                                                                     "
star:			.asciz "*"
points:			.asciz "points"
exit:			.asciz "You earned" 

.text
#------------------------------------------------------------------------------------------
# typing 
#	a typing game that allows the user to choose their difficulty, takes a peudo-random generator to 
#	choose the levels. Decrements a timer through a TIMER INTERRUPT and records user input from the 
#	keyboard via a KEYBOARD INTERRUPT
#
#	arguments: a0: address of the array of pointers to strings
#	returns: none
#------------------------------------------------------------------------------------------
typing:
	# save regs 
	addi sp,sp,-8			# sp <-- sp-8
	sw ra, 0(sp)			# 0(sp) <-- ra 
	sw s11, 4(sp)			# 4(sp_ <-- s11
	mv s11, a0			# s11 <-- base of the array to choose from 
	# save the handler into utvec
	la t0, handler			# t0 <-- address of the handler
	csrrw t1, 0x005, t0		# move handler to utvec 
	la a0, welcomeMessage		# this will print the welcome message 
	li a1, 0			# print on top corner 
	li a2, 0			# print on top corner 
	jal printStr			# goto printStr
	# enable ONLY keyboard its here, choosing level difficulty 
	la t0, KEYBOARD_CONTROL		# address to address of keyboard control
	lw t0, 0(t0)			# address of keybaord control 
	li t1, 0x02			# t2 <-- 2 (0010)
	sw t1, 0(t0)			# 0010 stored into KEYBOARD_CONTROL
	csrrwi zero, 0x000, 0x01	# set cause reg to enabled ints 
	li t1, 0x100			# hex code for the keyboard int, no timer ints yet 
	csrrw zero, 0x004, t1		# enable keyboard and timer ints 0001 0000 0000 (0x100)
	
	li t1, 1			# t1 <-- 1 (0001)
level_loop: 				# will stay here till user chooses a level 
	la t0, DIFFICULTY_CHOSEN	# address of the chosen indicator 
	lw t0, 0(t0)			# value of the chosen indicator 
	bnez t0, level_loop		# if chosen != 0 go again 
	# disable both interupts in uie to stop a LW error re enable after the string has been selected 
	csrrw zero, 0x004, zero		# enable keyboard and timer ints 0001 0001 0000 (0x110)
	li a0, 0			# a0 <-- 0; clear entire screen
	jal clearScreen			# clear the screen 
	# set up initial timer int 
	la t0, TIME			# address to address of TIME 
	lw t0, 0(t0)			# t0 <-- address of time 
	lw t0, 0(t0)			# t0 <-- actual time 
	la t1, TIMECMP			# address to adress of TIMPECMP 
	lw t1, 0(t1)			# load the timer cmp address  		
	addi t2, t0, 1			# t2 <-- next time interupt <---  1/1000s to make it come up instantly 			
	sw t2, 0(t1)			# time + 1000 ( 1 second) <-- TIMECMP
	
randomLevel: # chooses the random level with current random numbers =  13 10 18 5 23 0 3, remember 13 is line 14 of text file 
	jal random			# a0 <-- contains the random number for the string we use 
	slli a0,a0,2			# a0 <-- a0 * 4 
	add a0, a0, s11			# a0 <-- pointer to the pointer of the string we want 
	# load the string 
	lw a0, 0(a0)			# a0 <-- pointer to the string 	
	la t0, CURRENT_STRING		# save what string we are on to compare to
	sw a0, 0(t0)			# store the current string into CURRENT_STRING 
	li a1, 3			# print 3th row down 
	li a2, 0 			# print @ 0, 4,0
	jal printStr			# a0 is already loaded and ready 
	# print points 
	la a0, POINTS			# address of POINTS
	la a1, POINTS_STRING		# address of POINTS_STRING
	li a2, 1 			# a2 <-- 1 (meaning increment in the function)
	jal intToString			# goto intToString returns a0 which is the address to the string we want to print 
	li a1, 0			# row = 0 
	li a2, 0			# col = 0 
	jal printStr			# goto printStr 
	# print the points word after the incrementing counter  
	la a0, points			# address of the points string 
	li a1, 0 			# row = 0 
	li a2, 5			# col = 5 
	jal printStr			# goto printStr
	# enable both interupts in uie, we disabled becuase there is alot of instruction calls that we dont want interrupted 
	li t1, 0x110			# hex code for the ints 
	csrrw zero, 0x004, t1		# enable keyboard and timer ints 0001 0001 0000 (0x110)
	# print the first star under the character so the user knows what to type 
	la t0, STAR_COL			# address of the col location for the star 
	lw t1, 0(t0)			# integer of the location 
	la a0, star			# load * 
	li a1, 4			# 4th row 
	mv a2, t1			# load col value into argument 
	addi t1,t1,1			# incriment col location 
	sw t1, 0(t0)			# store back 
	jal printStr			# goto printStr
	
timer_loop:				# runtime of the game, exits when timer hits 0
	la t0, TIMER			# address of the address to time remaining  
	lw t0, 0(t0)			# gives the time remaining 
	la t1, NEXT_STAGE		# address of NEXT_STAGE flag
	lw t2, 0(t1)			# value of NEXT_STAGE flag  
	beqz t2, nextStage		# goto next stage if the flag = 0 
	la t3, TIMER_FLAG		# t3 <-- address of TIMER_FLAG
	la t4, KEYBOARD_FLAG		# t4 <-- address of KEYBOARD_FLAG
	lw t3, 0(t3)			# t3 <-- value of TIMER_FLAG
	lw t4, 0(t4)			# t4 <-- value of KEYBOARD_FLAG
	beqz t3, timer_int_happened	# if TIMER_FLAG == 0 goto timer_int_happened
	beqz t4, keyboard_int_happened 	# if KEYBOARD_FLAG == 0 goto keyboard_int_happened
	bge t0, zero, timer_loop	# while timer > = 0 goto timer_loop
	j exitTyping			# goto exitTyping 

timer_int_happened:			# branch here after a timer flag has been set 
	la a0, TIMER			# address to TIMER 
	la a1, TIMER_STRING		# address to TIMER_STRING
	li a2, 0			# a2 <-- 0, meaning decrement in the intToString function 
	jal intToString			# goto intToString; a0 <-- has the value to be printed a1 <- place to be stored as a string 
	li a1, 1			# row = 1 
	li a2, 0			# col = 0 
	jal printStr			# goto printStr 
	la t0, TIMER_FLAG		# re enable the flag
	li t1, 1			# t1 <-- 1 
	sw t1, 0(t0)			# TIMER_FLAG <-- 1
	j timer_loop 			# goto timer_loop
	
keyboard_int_happened:			# branch here after a keyboard flag has been set 
	la a0, POINTS			# a0 <-- address to POINTS 
	la a1, POINTS_STRING		# a1 <-- address to POINTS_STRING
	li a2, 1 			# a2 <-- 1, meaning the intToString will increment 
	jal intToString			# goto intToString; returns a0 which is the string we will print 
	li a1, 0			# row = 0 
	li a2, 0			# col = 0 
	jal printStr			# goto printStr 
	la t4, CURRENT_STRING		# address to address of the CURRENT_STRING 
	lw t6, 0(t4)			# addess of byte on current string 
	lb t5, 0(t6)			# current string value  
	la t3, KEYBOARD_DATA		# address to the address key press 
	lw t3, 0(t3)			# address of the button pressed 
	lw t3, 0(t3)			# value of the key 
	la t0, STAR_COL			# address of STAR_COL
	lw t1, 0(t0)			# col location 
	la a0, star			# address of the * we need to print 
	li a1, 4			# 4th row down always 
	mv a2, t1			# move col location into the aug reg 
	addi t1,t1,1			# increment col location 
	sw t1, 0(t0)			# save back into STAR_COL
	addi t6,t6,1			# increment the current string 
	sw t6, 0(t4)			# store back to CURRENT STRING 
	li t6, 46			# t6 <-- "." 
	beq t5, t6, done_level 		# if t5 == "." goto done_level
	li t6, 33			# t6 <-- "!" 	
	beq t5, t6, done_level 		# if t5 == "!" goto done_level
	li t6, 63			# t6 <-- "?" 	
	beq t5, t6, done_level 		# if t5 == "?" goto done_level
	jal printStr			# if t5 != ">", "!", "?" goto printStr 
	la t0, KEYBOARD_FLAG		# t0 <-- address to KEYBOARD_FLAG
	li t1, 1			# t1 <-- 1, to get the flag to 1 and reset the keyboard ints 
	sw t1, 0(t0)			# KEYBOARD_FLAG <-- 1 
	j timer_loop 			# goto timer_loop 
	
done_level:	# when a . / ! / ? is found we are done with this level 
	la t6, NEXT_STAGE		# set flag for the next stage 
	sw zero, 0(t6)			# NEXT_STAGE <- zero 
	jal printStr			# goto printStr 
	la t0, KEYBOARD_FLAG		# t0 <-- address of KEYBOARD_FLAG
	li t1, 1			# t1 <-- 1 to reset keyboard ints 
	sw t1, 0(t0)			# KEYBOARD_FLAG <-- 1
	j nextStage			# goto timer_loop 
	
nextStage: 	# disable both interupts in uie, we dont want a interupt while printing the new screen 
	csrrw zero, 0x004, zero		# disable keyboard and timer ints till everything is set up for the next stage 
	la t0, TIMER			# address of TIMER 
	lw t4, 0(t0)			# value of TIMER 
	la t1, BONUS_TIME		# address of BONUS_TIME 
	lw t1,0(t1)			# value of BONUS_TIME 
	la t2, NEXT_STAGE		# Address of NEXT_STAGE
	la t3, STAR_COL			# Address of STAR_COL
	li t5, 1			# to save into next stage to reset it 
	sw t5, 0(t2)			# NEXT_STAGE <-- 1 
	sw zero, 0(t3)			# STAR_COL <-- 0, reset the * location 
	add t4,t4,t1			# TIMER <-- TIMER + BONUS_TIME
	sw t4, 0(t0)			# save it to the address 
	li a0, 1			# a0 <-- 1; clear only 1/2 screen 
	jal clearScreen			# goto clearScreen 
	j randomLevel			# goto random level, takes new xi and gets a new random number 
	
exitTyping: # to return back to common.s REMEMBER TO STORE ALL S-REGS WE USE 	
	csrrwi zero, 0x000, 0x00	# disable ints when we go back to common.s 
	csrrwi zero, 0x004, 0x00	# set cause reg to disabled ints 
	li a0, 0			# a0 <-- 0; clear entire screen 
	jal clearScreen			# goto clearScreen
	# exit message before returning to common.s 
	la a0, gameOver			# a0 <-- address of gameOver message 
	li a1, 0			# row = 0 
	li a2, 0			# col = 0 
	jal printStr			# goto printStr
	la a0, exit			# a0 <-- address of exit message 
	li a1, 1			# row = 1
	li a2, 0			# col = 0 
	jal printStr			# goto printStr
	la a0, POINTS_STRING		# a0 <-- address of total points earned 
	li a1, 1			# row = 1 
	li a2, 11			# col = 11 
	jal printStr			# goto printStr
	la a0, points			# a0 <-- address to points message
	li a1, 1			# row = 0 
	li a2, 15			# col = 15 
	jal printStr			# goto printStr 
	lw ra, 0(sp)			# ra <-- 0(sp)
	lw s11, 4(sp)			# s11 <-- 4(sp)
	addi sp,sp,8			# increment sp 
	jr ra 				# goto common.s 
	
#------------------------------------------------------------------------------------------
# intToString
# takes a integer input and converts it to a string 
#	arguments: a0: address of the integer to convert
#		   a1: address of the string location to save it to  
#		   a2: 0 = decrement orig int; 1= increment orig int 
#	returns: a0: address of the string the decimal was converted into
#------------------------------------------------------------------------------------------
intToString:
	lw t0, 0(a0)			# t0 <-- value of integer
	li t2, 100			# t2 <-- 100 
	li t3, 10			# t3 <-- 10
	li t4, 1			# t4 <-- 1 
	divu t1, t0, t2			# t1 <-- input / 100 
	addi t1,t1,48			# decimal to ascii
	sb t1, 0(a1)			# store t1 in 0th bit 
	remu t1, t0, t2			# t1 <-- REM OF input / 100
	divu t5, t1, t3			# t1 <-- rem of p1 / 10
	addi t5,t5,48			# decimal to ascii
	sb t5, 1(a1)			# store t5 into 1st bit 
	remu t5, t1, t3			# t5 <-- REM OF input / 100 
	divu t1, t5, t4			# t1 <-- rem of p2 / 1
	addi t1,t1,48			# decimal to ascii
	sb t1, 2(a1)			# store t1 in 2nd bit 
	remu t1, t5, t4			# t5 <-- REM OF input / 100 
	li t2, 0			# t2 <-- 0; load null 
	sb t2, 3(a1)			# store null in 3rd bit 
	beqz a2, decrement		# if a2 = 0 goto decrement, if not will go to increment
# normally i would but a ecall here for a error if nothing was entered into a2, but it says no ecalls 
# i will just have it increment by default if there is nothing in a2
increment:	# used to increment POINTS 
	addi t0,t0, 1			# increment timer 
	sw t0, 0(a0)			# store timer
	j done_intToString 		# goto done_intToString
decrement:	# used to decrement TIMER 
	addi t0,t0,-1			# increment timer 
	sw t0, 0(a0)			# store timer
	j done_intToString 		# goto done_intToString 
done_intToString:	
	mv a0,a1			# move a1 location of the string to a0 for return 
	jr ra				# goto ra 

#------------------------------------------------------------------------------------------
# Random:
# 	Starts at the xi entered in the program outline and saved it back into that memory location for the
# 	next iteration of random 
#
#	arguments: None 
#	returns: the next random number 
#------------------------------------------------------------------------------------------
random: # no s-regs to save, didnt use any 
	la t0, XiVar			# t0 <-- X[i-1]
	la t2, aVar			# t1 <--- address of a
	la t3, cVar			# t2 <--- address of c
	la t4, mVar			# t3 <--- address of m 
	lw t1, 0(t0)			# t1 <-- Xi
	lw t2, 0(t2)			# t2 <-- a 
	lw t3, 0(t3)			# t3 <-- c
	lw t4, 0(t4)			# t4 <-- m
	mul t5, t2, t1			# t5 <-- a * Xi
	add t5, t5, t3			# t5 <-- (a*Xi) + c
	rem t5,t5,t4			# t5 <-- ((a*Xi) + c) % m 
	sw t5, 0(t0)			# store back into the mem location of Xi
	mv a0, t5 			# move to a0 to return 
   	jr ra 				# goto ra 

#------------------------------------------------------------------------------
# clearScreen:
# 	Clears the screen when called 
# 	Args: a0, full clear or bottom clear  
# 	Returns: None 
#------------------------------------------------------------------------------
clearScreen:
	addi sp,sp,-20			# sp <-- sp-20
	sw ra, 0(sp)			# 0(sp) <-- ra 
	sw s0, 4(sp)			# 4(sp) <-- s0
	sw s1, 8(sp)			# 8(s0) <-- s1 
	sw s2, 12(sp)			# 12(sp) <-- s2 
	sw s3, 16(sp)			# 16(sp) <-- s3 
	la s0, clear			# empty string to clear screen with 
	bnez a0, half_clear		# if a0  = 0 we half clear (start at 4th row)
	li s1, 0			# clear entire screen 
	j continue
half_clear:
	li s1, 3			# half clear 
continue:
	li s2, 0			# starting column 
	li s3, 6			# max rows to clear which is 6 (full clear)
	mv a0, s0			# a0 <-- s0
	mv a1, s1			# a1 <-- s1 			
	mv a2, s2			# a2 <-- s2 

clearLoop:# prints over all the rows to clear the screen starting @ 0,20 to 6, 20
	jal printStr			# goto PrintStr
	mv a0, s0			# a0 <-- s0
	mv a1, s1			# a1 <-- s1
	mv a2, s2			# a2 <-- s2 
	addi s1,s1,1			# s1 ,-- s1 + 1 
	blt s1, s3, clearLoop		# if row != 6 goto clearLoop 
	lw ra, 0(sp)			# ra <-- 0(sp)
	lw s0, 4(sp)			# s0 <-- 4(sp)
	lw s1, 8(sp)			# s1 <-- 8(sp)
	lw s2, 12(sp)			# s2 <-- 12(sp)
	lw s3, 16(sp)			# s3 <-- 16(sp)
	addi sp,sp,20			# sp <-- sp + 20 
	jr ra 				# goto ra 
	
#------------------------------------------------------------------------------
# handler:
# 	Interupt handler for timer and keyboard interupts. Will set a flag bit 
# 	in the interrupt handler and the function outside of the handler will 
# 	deal with it 
# 	Args: None 
# 	Returns: None 
#------------------------------------------------------------------------------
handler: # uscratch remains in a0 the whole time, make sure not to use it, or save it 
	# turn off interupts while in the handler 
	csrrwi zero, 0x004, 0x00	# set cause reg to disabled ints 
	csrrw a0, 0x040, a0		# a0 <--- address of itrap, uscratch <-- USERa0
	sw t0, 0(a0)			# 0(USCRATCH) <-- t0
	sw t1, 4(a0)			# 4(USCRATCH) <-- t1
	sw t2, 8(a0)			# 8(USCRATCH) <-- t2
	sw t3, 12(a0)			# 12(USCRATCH) <-- t3
	sw t4, 16(a0)			# 16(USCRATCH) <-- t4
	sw t5, 20(a0)			# 20(USCRATCH) <-- t5
	sw t6, 24(a0)			# 22(USCRATCH) <-- t6
	sw a1, 28(a0)			# 24(USCRATCH) <-- a1
	sw a2, 32(a0)			# 32(USCRATCH) <-- a2
	sw s0, 36(a0)			# 34(USCRATCH) <-- s0
	sw ra, 40(a0)			# 36(USCRATCH) <-- ra
	csrr t0, 0x040			# t0 <--- USRa0  
	sw t0, 44(a0)			# 40(USCRATCH) <-- USR a0
	# check what kind of exception occured 
	li t1,0				# t1 <-- 0 
	csrrw t0, 0x42, t1		# move cause to t0 and clear 
	li t1, 0x7FFFFFFF		# mask everything but last bit 
	and s0,t0,t1			# s0 <--- cause code 
	li t2, 4			# cause code for timer ints
	li t3, 8			# cause code for keyboard ints 
	beq t2,s0, timer		# jump to timer handler
	beq t3, s0, keyboard		# jump to keyboard handler
	j handlerTerminate		# if it wasnt timer or keyboard exit program 
	
timer:  # handle timer interupt, set a flag to decrement time outside of handler 
	la t0, TIME			# t0 <-- address to address of TIME 
	la t1, TIMECMP			# t1 <-- address of the address of TIMECMP
	lw t1, 0(t1)			# t1 <-- address of TIMECMP 
	lw t0, 0(t0)			# t0 <-- current TIME address
	lw t0, 0(t0)			# t0 <-- current TIME value 
	addi t2, t0, 1000		# t2 <-- next TIME int i.e TIME = TIME + 1000
	sw t2, 0(t1)			# TIMECMP <-- TIME + 1000 
	la t0, TIMER_FLAG		# address of TIMER_FLAG
	sw zero, 0(t0)			# TIMER_FLAG <-- 0 (enabled) will branch outside of handler 
	j handlerReturn 		# goto handlerReturn
	
keyboard: # handle keyboard interupt, the point is to get input from the user and set flag to update the screen outside of handler 
	la t0, DIFFICULTY_CHOSEN 	# t0 <-- address of DIFFICULTY_CHOSEN
	lw t0, 0(t0)			# value needs to be 0 to skip difficulty selection 
	beqz t0, difficulty_chosen	# if the value is 0 we skip difficulty because they chose the level already 

difficulty: # will wait for the user to enter 1 2 3 and then assign a difficulty.
	li t0, 49			# t0 <-- 1 in ascii 
	li t1, 50			# t1 <-- 2 in ascii
	li t2, 51			# t3 <-- 3 in ascii 
	la t3, KEYBOARD_DATA		# address to the address of KEYBOARD_DATA
	lw t3, 0(t3)			# address of KEYBOARD_DATA
	lw t3, 0(t3)			# value of KEYBOARD_DATA
	beq t0, t3, level_success_1	# level one chosen
	beq t1, t3, level_success_2	# level 2 chosen 
	beq t2, t3, level_success_3	# level 3 chosen 
	j handlerReturn			# goto handlerReturn, they chose nothing 
	
level_success_1: # level 1 selected, initial time = 60, bonus time = 12 
	la t0, TIMER			# address of TIMER 
	la t1, BONUS_TIME		# address of BONIUS_TIME 
	la t2, DIFFICULTY_CHOSEN	# address of DIFFICULTY_CHOSEN to tell timer a choice has been made 
	li t3, 60 			# t3 <-- 60 STARTING TIME 
	li t4, 12 			# t4 <-- 12 BONUS TIME 
	sw t3, 0(t0)			# SAVE NEW STARTING TIME 
	sw t4, 0(t1)			# SAVE NEW BONUS TIME 
	sw zero, 0(t2)			# set flag to know a choice has been made 
	j handlerReturn 		# goto handlerReturn

level_success_2: # level 2 selected, initial time = 30, bonus time = 6 
	la t0, TIMER			# address of TIMER 
	la t1, BONUS_TIME		# address of BONIUS_TIME 
	la t2, DIFFICULTY_CHOSEN	# address of DIFFICULTY_CHOSEN to tell timer a choice has been made 
	li t3, 30 			# t3 <-- 30 STARTING TIME 
	li t4, 6			# t4 <-- 6 BONUS TIME 
	sw t3, 0(t0)			# SAVE NEW STARTING TIME 
	sw t4, 0(t1)			# SAVE NEW BONUS TIME 
	sw zero, 0(t2)			# set flag to know a choice has been made 
	j handlerReturn 		# goto handlerReturn

level_success_3: # level 3 selected, inital time = 20, bonus time = 4
	la t0, TIMER			# address of TIMER 
	la t1, BONUS_TIME		# address of BONIUS_TIME 
	la t2, DIFFICULTY_CHOSEN	# address of DIFFICULTY_CHOSEN to tell timer a choice has been made 
	li t3, 20			# t3 <-- 20 STARTING TIME 
	li t4, 4 			# t4 <-- 4 BONUS TIME 
	sw t3, 0(t0)			# SAVE NEW STARTING TIME 
	sw t4, 0(t1)			# SAVE NEW BONUS TIME 
	sw zero, 0(t2)			# set flag to know a choice has been made 
	j handlerReturn 		# goto handlerReturn 

difficulty_chosen: # after the user chooses difficulty no need to do the branchs 
	la t4, CURRENT_STRING		# address to address of the current 
	lw t6, 0(t4)			# addess of byte on current string 
	lb t5, 0(t6)			# current string value  
	la t3, KEYBOARD_DATA		# address to the address key press 
	lw t3, 0(t3)			# address of the button pressed 
	lw t3, 0(t3)			# value of the key 
	beq t5, t3, match		# if the text matchs it will set a flag 
	j handlerReturn			# goto handlerReturn 
	
match:	# if the text matchs set flag 
	la t0, KEYBOARD_FLAG		# address to KEYBOARD_FLAG
	sw zero, 0(t0)			# KEYBOARD_FLAG <-- 0 
	j handlerReturn			# goto handlerReturn 
	
handlerReturn: 
	# re enable UIE timer interupts before we leave ?
   	li t1, 0x110			# load 4 into UIE to enable timer interupts 
   	csrrw zero, 0x04, t1		# CSR4 = UIE = 0001 0001 0000
   	# enable keyboard ints after we done handleing 
	la t0, KEYBOARD_CONTROL		# address to address of keyboard control
	lw t0, 0(t0)			# address of keybaord control 
	li t1, 0x02			# t1 <-- 0010
	sw t1, 0(t0)			# KEYBOARD_CONTROL <-- 0010
      	# restore all the  registers 
   	lw t0, 44(a0)			# t0 <-- USRa0
   	csrw t0, 0x040			# uscratch <-- USRa0
	lw t0, 0(a0)			# t0 <-- 0(USCRATCH)
	lw t1, 4(a0)			# t1 <-- 4(USCRATCH)
	lw t2, 8(a0)			# t2 <-- 8(USCRATCH)
	lw t3, 12(a0)			# t3 <-- 12(USCRATCH)
	lw t4, 16(a0)			# t4 <-- 16(USCRATCH)
	lw t5, 20(a0)			# t5 <-- 20(USCRATCH)
	lw t6, 24(a0)			# t6 <-- 24(USCRATCH)
	lw a1, 28(a0)			# a1 <-- 28(USCRATCH)
	lw a2, 32(a0)			# a2 <-- 32(USCRATCH)
	lw s0, 36(a0)			# s0 <-- 36(USCRATCH)
	lw ra, 40(a0)			# ra <-- 40(USCRATCH)
   	csrrw a0, 0x040, a0		# a0 <-- USRa0, uscratch <-- addr itrapdata 
   	uret				# return from the handler, dont increment b/c it was a interupt not a exception. 
	
	
# taken from the example file only did slight modifications 
#------------------------------------------------------------------------------
# printStr
# Args:
# 	a0: strAddr - The address of the null-terminated string to be printed.
# 	a1: row - The row to print on.
# 	a2: col - The column to start printing on.
#
# Prints a string in the Keyboard and Display MMIO Simulator terminal at the
# given row and column.
#------------------------------------------------------------------------------
printStr:
	# Stack
	addi	sp, sp, -16
	sw	ra, 0(sp)
	sw	s0, 4(sp)
	sw	s1, 8(sp)
	sw	s2, 12(sp)
	
	mv	s0, a0
	mv	s1, a1
	mv	s2, a2
	printStrLoop:
		# Check for null-character
		lb	t0, 0(s0)	# t0 <- char = str[i]
		# needed to check for new line also 
		li t1, 10
		bne t0, t1, dontMakeNull
		li t0, 0
		# Loop while(str[i] != '\0')
dontMakeNull:
		beq	t0, zero, printStrLoopEnd
		
		# Print character
		mv	a0, t0		# a0 <- char
		mv	a1, s1		# a1 <- row
		mv	a2, s2		# a2 <- col
		jal	printChar
		
		addi	s0, s0, 1	# i++
		addi	s2, s2, 1	# col++
		j	printStrLoop
	printStrLoopEnd:
	
		# Unstack
		lw	ra, 0(sp)
		lw	s0, 4(sp)
		lw	s1, 8(sp)
		lw	s2, 12(sp)
		addi	sp, sp, 16
		jalr	zero, ra, 0

# taken from the example file only did slight modifications 
#------------------------------------------------------------------------------
# printChar
# Args:
#	a0: char - The character to print
#	a1: row - The row to print the given character
#	a2: col - The column to print the given character
#
# Prints a single character to the Keyboard and Display MMIO Simulator terminal
# at the given row and column.
#------------------------------------------------------------------------------
printChar:
	# Stack
	addi	sp, sp, -16
	sw	ra, 0(sp)
	sw	s0, 4(sp)
	sw	s1, 8(sp)
	sw	s2, 12(sp)
	
	# Save parameters
	add	s0, a0, zero
	add	s1, a1, zero
	add	s2, a2, zero
	
	jal	waitForDisplayReady	# Wait for display before printing
	
	# Load bell and position into a register
	addi	t0, zero, 7	# Bell ascii
	slli	s1, s1, 8	# Shift row into position
	slli	s2, s2, 20	# Shift col into position
	or	t0, t0, s1
	or	t0, t0, s2	# Combine ascii, row, & col
	
	# Move cursor
	lw	t1, DISPLAY_DATA
	sw	t0, 0(t1)
	
	jal	waitForDisplayReady	# Wait for display before printing
	
	# Print char
	lw	t0, DISPLAY_DATA
	sw	s0, 0(t0)
	
	# Unstack
	lw	ra, 0(sp)
	lw	s0, 4(sp)
	lw	s1, 8(sp)
	lw	s2, 12(sp)
	addi	sp, sp, 16
	jalr    zero, ra, 0

# taken from the example file only did slight modifications 
#------------------------------------------------------------------------------
# waitForDisplayReady
#
# A method that will check if the Keyboard and Display MMIO Simulator terminal
# can be writen to, busy-waiting until it can.
#------------------------------------------------------------------------------
waitForDisplayReady:
	# Loop while display ready bit is zero
	
	lw	t0, DISPLAY_CONTROL
	lw	t0, 0(t0)
	andi	t0, t0, 1
	beq	t0, zero, waitForDisplayReady
	jalr    zero, ra, 0



handlerTerminate:
	# Print error msg before terminating
	li	a7, 4
	la	a0, INTERRUPT_ERROR
	ecall
	li	a7, 34
	csrrci	a0, 66, 0
	ecall
	li	a7, 4
	la	a0, INSTRUCTION_ERROR
	ecall
	li	a7, 34
	csrrci	a0, 65, 0
	ecall
handlerQuit:
	li	a7, 10
	ecall	# End of program
