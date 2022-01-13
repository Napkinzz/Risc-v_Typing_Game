.include "common.s"

.data
.align 16
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

# taken from displayDemo.s 
INTERRUPT_ERROR:	.asciz "Error: Unhandled interrupt with exception code: "
INSTRUCTION_ERROR:	.asciz "\n   Originating from the instruction at address: "
# my strings 
welcomeMessage:		.asciz "Please enter 1 2 3 to choose the level and start the game: "
timerWorking:		.asciz "The timer is working here"
keyboardWorking:	.asciz "The keyboard is working here"
inTimer:		.asciz "|||||Inside Timer||||| "
inIntToString:		.asciz "|||||Inside intToString||||| "
backTimer:		.asciz "||||| Back Inside Timer||||| "
storedToTIMECMP:	.asciz "||||| STORED TO TIMECMP ||||| "
insideHandlerReturn:	.asciz "||||| INSIDE HANDLER RETURN||||| "
insideKeyboardInt:	.asciz "||||| INSIDE KEYBOARD INT||||| "
space:			.asciz "  " 
gameOver:		.asciz "GAME OVER! "
clear: 			.asciz "                                                                                                                     "
star:			.asciz "*"
points:			.asciz "points"
exit:			.asciz "You earned" 

.text
typing:
	# save regs 
	addi sp,sp,-8
	sw ra, 0(sp)
	sw s11, 4(sp)
	
	
	mv s11, a0			# s11 <-- base of the array to choose from 
	# save the handler into utvec
	la t0, handler
	csrrw t1, 0x005, t0		# move handler to utvec 
	
	# the welcome message 
	la a0, welcomeMessage		# this will print the welcome message 
	li a1, 0			# print on top corner 
	li a2, 0			# print on top corner 
	jal printStr
	
#------------------------------------------------------------------------------------------
# 	Testing random 
#	jal random
#	li a7,1
#	ecall
#	la a0, space
#	li a7, 4
#	ecall
#------------------------------------------------------------------------------------------

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
	jal clearScreen			# clear the screen 
	
	# set up initial timer int 
	la t0, TIME			# address to address of TIME 
	lw t0, 0(t0)			# t0 <-- address of time 
	lw t0, 0(t0)			# t0 <-- actual time 
	la t1, TIMECMP			# address to adress of TIMPECMP 
	lw t1, 0(t1)			# load the timer cmp address  		
	addi t2, t0, 1			# t2 <-- next time interupt <---  1/1000s to make it come up instantly 			
	sw t2, 0(t1)			# time + 1000 ( 1 second) <-- TIMECMP


randomLevel:

	
	jal random			# a0 <-- contains the random number for the string we use 
	slli a0,a0,2			# a0 <-- a0 * 4 
	add a0, a0, s11			# a0 <-- pointer to the pointer of the string we want 
	
	lw a0, 0(a0)			# a0 <-- pointer to the string 	
	
	la t0, CURRENT_STRING		# save what string we are on to compare to
	sw a0, 0(t0)			# store the current string into CURRENT_STRING 
	
	li a1, 3			# print 3th row down 
	li a2, 0 			# print @ 0, 4,0
	jal printStr			# a0 is already loaded and ready 
	
	# print points 
	la a0, POINTS
	la a1, POINTS_STRING
	li a2, 1 
	jal intToString			# returns a0 which is the string we will print 
	li a1, 0
	li a2, 0
	jal printStr
	
	# print the points string 
	la a0, points			# address of the points string 
	li a1, 0 			# row = 0 
	li a2, 5			# col = 5 
	jal printStr
	
	# enable both interupts in uie 
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
	jal printStr
	
timer_loop:				# runtime of the game, exits when timer hits 0
	la t0, TIMER			# address of the address to time remaining  
	lw t0, 0(t0)			# gives the time remaining 
	
	la t1, NEXT_STAGE		# address of next stage 
	lw t2, 0(t1)			# value of next stage 
	beqz t2, nextStage		# goto next stage if the flag = 0 
	bge t0, zero, timer_loop	# while timer > = 0  
	j exitTyping
	
nextStage:
	# disable both interupts in uie, we dont want a interupt while printing the new screen 
	csrrw zero, 0x004, zero		# enable keyboard and timer ints 0001 0001 0000 (0x110)
	
	la t0, TIMER			# address of timer 
	lw t4, 0(t0)			# value of timer 
	
	la t1, BONUS_TIME		# address of BONUS_TIME 
	lw t1,0(t1)			# value of BONUS_TIME 
	
	la t2, NEXT_STAGE		# Address of NEXT_STAGE
	la t3, STAR_COL			# Address of STAR_COL
	
	li t5, 1			# to save into next stage to reset it 
	sw t5, 0(t2)			# NEXT_STAGE <-- 1 
	
	sw zero, 0(t3)			# STAR_COL <-- 0 
	
	add t4,t4,t1			# TIMER <-- TIMER + BONUS_TIME
	sw t4, 0(t0)			# save it to the address 
	jal clearScreen
	j randomLevel
	
	
exitTyping: # to return back to common.s REMEMBER TO STORE ALL S-REGS WE USE 	
	csrrwi zero, 0x000, 0x00		# disable ints when we go back to common.s 
	csrrwi zero, 0x004, 0x00		# set cause reg to disabled ints 
	
	jal clearScreen
	# exit message before returning to common.s 
	la a0, gameOver		
	li a1, 0			
	li a2, 0
	jal printStr
	la a0, exit
	li a1, 1
	li a2, 0
	jal printStr
	la a0, POINTS_STRING
	li a1, 1
	li a2, 11
	jal printStr
	la a0, points
	li a1, 1
	li a2, 15
	jal printStr

	lw ra, 0(sp)			# restore all regs 
	lw s11, 4(sp)			# restore all regs 
	addi sp,sp,8			# increment sp 
	jr ra 				# to common.s 
	
	
	
	
	
handler: # save every register we use throughout the handler 
	# turn off interupts while in the handler 
	csrrwi zero, 0x004, 0x00		# set cause reg to disabled ints 
	csrrw a0, 0x040, a0		# a0 <--- address of itrap, uscratch <-- USERa0
	sw t0, 0(a0)
	sw t1, 4(a0)
	sw t2, 8(a0)
	sw s0, 12(a0)
	sw t3, 16(a0)
	sw a1, 20(a0)
	sw a2, 24(a0)			
	sw ra, 28(a0)			# save all the registers we use 
	csrr t0, 0x040			# t0 <--- USRa0 uscratch <-- itrap ## maybe bug here changed t0 to a0 
	sw t0, 32(a0)			# save USR a0:   everything is saved now
	 
	# check what kind of exception occured 
	li t1,0
	csrrw t0, 0x42, t1		# move cause to t0 and clear 
	li t1, 0x7FFFFFFF		# mask everything but last bit 
	and s0,t0,t1			# s0 <--- cause code 
	li t2, 4			# cause code for timer ints
	li t3, 8			# cause code for keyboard ints 
	beq t2,s0, timer		# jump to timer handler
	beq t3, s0, keyboard		# jump to keyboard handler
	j handlerTerminate		# if it wasnt timer or keyboard exit program 
	
	
timer:  # handle timer interupt, the point is to display a countdown on the screen
#------------------------------------------------------------------------------------------
#	la a0, inTimer			# PRINTS INSIDE TIMER 
# 	li a7, 4
# 	ecall
#------------------------------------------------------------------------------------------
	la a0, TIMER
	la a1, TIMER_STRING
	li a2, 0			# for decrement 
	jal intToString			# a0 <-- has the value to be printed a1 <- palce to be stored as a string 
#------------------------------------------------------------------------------------------
#	mv t0,a0			# PRINTS BACK INSIDE TIMER 
#	la a0, backTimer
#	li a7,4 
#	ecall
#	mv a0, t0
#------------------------------------------------------------------------------------------
	li a1, 1			# this is just the position of the timer 
	li a2, 0
	jal printStr
	
	la t0, TIME
	la t1, TIMECMP			# t1 <-- address of the address of TIMECMP
	lw t1, 0(t1)			# t1 <-- address of TIMECMP 

	# add 1 second to time 
	lw t0, 0(t0)			# t0 <-- current time address
	lw t0, 0(t0)			# t0 <-- current time value 
	addi t2, t0, 1000		# t2 <-- next time int 
	# store into timecmp
	
	sw t2, 0(t1)			# store to the address of TIMECMP	
#------------------------------------------------------------------------------------------
#	la a0, storedToTIMECMP		# PRINT STORED DEBUG 
#	li a7, 4
#	ecall
#	mv a0, t2
#	li a7, 1
#	ecall 
#------------------------------------------------------------------------------------------
	j handlerReturn 
	
# handle keyboard interupt, the point is to get input from the user and update the screen 
keyboard:
#------------------------------------------------------------------------------------------
#	la a0, insideKeyboardInt	# for debugging 
#	li a7, 4
#	ecall	
#------------------------------------------------------------------------------------------
	la t0, DIFFICULTY_CHOSEN 	# t0 <-- address to if a choice was made yet 
	lw t0, 0(t0)			# value needs to be 0 to skip difficulty selection 
	beqz t0, difficulty_chosen	# if the value is 0 we skip difficulty because they chose the level 

difficulty:
	li t0, 49			# t0 <-- 1 in ascii 
	li t1, 50			# t1 <-- 2 in ascii
	li t2, 51			# t3 <-- 3 in ascii 
	la t3, KEYBOARD_DATA		# address to the address key press 
	lw t3, 0(t3)			# address of the button pressed 
	lw t3, 0(t3)			# value of the key 

	beq t0, t3, level_success_1	# level one chosen
	beq t1, t3, level_success_2	# level 2 chosen 
	beq t2, t3, level_success_3	# level 3 chosen 
	j handlerReturn			# no level chosen 
	
# level 1 selected, initial time = 60, bonus time = 12 
level_success_1:
	la t0, TIMER			# address of TIMER 
	la t1, BONUS_TIME		# address of BONIUS_TIME 
	la t2, DIFFICULTY_CHOSEN	# address of DIFFICULTY_CHOSEN to tell timer a choice has been made 
	li t3, 60 			# t3 <-- 60 STARTING TIME 
	li t4, 12 			# t4 <-- 12 BONUS TIME 
	sw t3, 0(t0)			# SAVE NEW STARTING TIME 
	sw t4, 0(t1)			# SAVE NEW BONUS TIME 
	sw zero, 0(t2)			# set flag to know a choice has been made 
	j handlerReturn 
# level 2 selected, initial time = 30, bonus time = 6 
level_success_2:
	la t0, TIMER			# address of TIMER 
	la t1, BONUS_TIME		# address of BONIUS_TIME 
	la t2, DIFFICULTY_CHOSEN	# address of DIFFICULTY_CHOSEN to tell timer a choice has been made 
	li t3, 30 			# t3 <-- 30 STARTING TIME 
	li t4, 6			# t4 <-- 6 BONUS TIME 
	sw t3, 0(t0)			# SAVE NEW STARTING TIME 
	sw t4, 0(t1)			# SAVE NEW BONUS TIME 
	sw zero, 0(t2)			# set flag to know a choice has been made 
	j handlerReturn 
# level 3 selected, inital time = 20, bonus time = 4
level_success_3:
	la t0, TIMER			# address of TIMER 
	la t1, BONUS_TIME		# address of BONIUS_TIME 
	la t2, DIFFICULTY_CHOSEN	# address of DIFFICULTY_CHOSEN to tell timer a choice has been made 
	li t3, 20			# t3 <-- 20 STARTING TIME 
	li t4, 4 			# t4 <-- 4 BONUS TIME 
	sw t3, 0(t0)			# SAVE NEW STARTING TIME 
	sw t4, 0(t1)			# SAVE NEW BONUS TIME 
	sw zero, 0(t2)			# set flag to know a choice has been made 
	j handlerReturn 

difficulty_chosen:
	
	la t4, CURRENT_STRING		# address to address of the current 
	lw t6, 0(t4)			# addess of byte on current string 
	lb t5, 0(t6)			# current string value  
	
	la t3, KEYBOARD_DATA		# address to the address key press 
	lw t3, 0(t3)			# address of the button pressed 
	lw t3, 0(t3)			# value of the key 
	
	beq t5, t3, match
	j handlerReturn
	
match:
	# print points 
	la a0, POINTS
	la a1, POINTS_STRING
	li a2, 1 
	jal intToString			# returns a0 which is the string we will print 
	li a1, 0
	li a2, 0
	jal printStr
	
	# reload because we need a function call above 
	la t4, CURRENT_STRING		# address to address of the current 
	lw t6, 0(t4)			# addess of byte on current string 
	lb t5, 0(t6)			# current string value  
	
	la t3, KEYBOARD_DATA		# address to the address key press 
	lw t3, 0(t3)			# address of the button pressed 
	lw t3, 0(t3)			# value of the key 
	
	la t0, STAR_COL			# address of STAR_COL
	lw t1, 0(t0)			# col location 
	la a0, star			# address of the * we need to print 
	li a1,4				# 4th row down always 
	mv a2, t1			# move col location into the aug reg 
	addi t1,t1,1			# increment col location 
	sw t1, 0(t0)			# save back into STAR_COL
	addi t6,t6,1			# increment the current string 
	sw t6, 0(t4)			# store back to CURRENT STRING 
	
	li t6, 46			# t6 <-- "." 
	beq t5, t6, period 
	li t6, 33			# t6 <-- "!" 	
	beq t5, t6, period 
	li t6, 63			# t6 <-- "?" 	
	beq t5, t6, period 
	
	jal printStr
	j handlerReturn
period:	# when a peroid is found we are done this level
	la t6, NEXT_STAGE		# set flag for the next stage 
	sw zero, 0(t6)			# set to zero 
	jal printStr
	j handlerReturn
	
	
		
handlerReturn: # to restore everything and leave the handler
#------------------------------------------------------------------------------------------
#	la a0, insideHandlerReturn
#	li a7,4
#	ecall
#------------------------------------------------------------------------------------------
	# re enable UIE timer interupts before we leave ?
   	li t1, 0x110			# load 4 into UIE to enable timer interupts 
   	csrrw zero, 0x04, t1		# CSR4 = UIE = 0001 0001 0000
   	
   	# enable keyboard ints after we done handleing 
	la t0, KEYBOARD_CONTROL		# address to address of keyboard control
	lw t0, 0(t0)			# address of keybaord control 
	li t1, 0x02
	sw t1, 0(t0)
   	
      	# restore all the used registers 
   	la a0, iTrapData		# a0 <-- address of itrapdata, probably have to change this 
   	lw t0, 32(a0)			# t0 <-- USRa0
   	csrw t0, 0x040			# uscratch <-- USRa0
   	lw t0, 0(a0)			#load the registers again 
   	lw t1, 4(a0)
   	lw t2, 8(a0)
   	lw s0, 12(a0)
   	lw t3, 16(a0)
	lw a1, 20(a0)
	lw a2, 24(a0)	
	lw ra, 28(a0)
   	csrrw a0, 0x040, a0		# a0 <-- USRa0, uscratch <-- addr itrapdata 
 
   	uret				# return from the handler, dont increment b/c it was a interupt not a exception. 
		

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
	
	divu t1, t0, t2			# t1 <-- integer / 100 
	addi t1,t1,48			# decimal to ascii
	sb t1, 0(a1)			# store t1 in 0th bit 
	remu t1, t0, t2			# t1 <-- REM OF integer / 100
	
	divu t5, t1, t3			# t1 <-- rem of p1 / 10
	addi t5,t5,48			# decimal to ascii
	sb t5, 1(a1)			# store t5 into 1st bit 
	remu t5, t1, t3			# t5 <-- REM OF integer / 100 
	
	divu t1, t5, t4			# t1 <-- rem of p2 / 1
	addi t1,t1,48			# decimal to ascii
	sb t1, 2(a1)			# store t1 in 2nd bit 
	remu t1, t5, t4			# t5 <-- REM OF integer / 100 
	
	li t2, 0			# load null 
	sb t2, 3(a1)			# store null in 3rd bit 
	beqz a2, decrement
# noramlly i would but a ecall here for a error if nothing was entered into a2, but it says no ecalls 
# i will just have it increment by default if there is nothing in a2
increment:
	addi t0,t0, 1			# increment timer 
	sw t0, 0(a0)			# store timer
	j done_intToString 
decrement:
	addi t0,t0,-1			# increment timer 
	sw t0, 0(a0)			# store timer
	j done_intToString 
#------------------------------------------------------------------------------------------	
#	la a0, inIntToString		# PRITNS INDSIDE STRING DEBUG 
#	li a7, 4
#	ecall 
#------------------------------------------------------------------------------------------
done_intToString:	
	mv a0,a1
	jr ra



#------------------------------------------------------------------------------------------
# Random
# Starts at the xi entered in the program outline and saved it back into that memory location for the
# next iteration of random 
#	arguments: None 
#	returns: the next random number 
#
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
   	jr ra 				# jump back 



#------------------------------------------------------------------------------
# clearScreen 
# Args: None 
# Returns: None 
# Clears the screen when called 
#------------------------------------------------------------------------------
clearScreen:
	addi sp,sp,-20		# save ra 
	sw ra, 0(sp)
	sw s0, 4(sp)
	sw s1, 8(sp)
	sw s2, 12(sp)
	sw s3, 16(sp)
	
	la s0, clear		# empty string to clear screen with 
	li s1, 0		# row
	li s2, 0		# column 
	li s3, 10		# max rows 
	
	mv a0, s0		# set argumetns to the function call 
	mv a1, s1
	mv a2, s2
# prints over all the rows to clear the screen starting @ 0,0 to 10, 0
clearLoop:
	jal printStr		# clear row 
	mv a0, s0		# set arguments for funstion call 
	mv a1, s1
	mv a2, s2
	addi s1,s1,1		# increment row 
	blt s1, s3, clearLoop	# brack back up if row != 10 
	lw ra, 0(sp)		# restore ra and leave 
	lw s0, 4(sp)
	lw s1, 8(sp)
	lw s2, 12(sp)
	lw s3, 16(sp)
	addi sp,sp,20
	jr ra 
	
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
