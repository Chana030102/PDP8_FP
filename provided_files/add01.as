/ Program : Add01.pal
/ Date : March 3, 2002
/
/ Desc : This program computes c = a + b
/
/-------------------------------------------
/
/ Code Section
/
*0200			/ start at address 0200
Main, 	cla cll 	/ clear AC and Link
	tad A 		/ add A to Accumulator
	tad B 		/ add B
	dca C 		/ store sum at C
	hlt 		/ Halt program
	jmp Main	/ To continue - goto Main
/
/ Data Section
/
*0250 			/ place data at address 0250
A, 	2 		/ A equals 2
B, 	3 		/ B equals 3
C, 	0
$Main 			/ End of Program; Main is entry point
