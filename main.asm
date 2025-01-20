INCLUDE Irvine32.inc
INCLUDE Macros.inc

.data

	;list of all words & positions necessary
	paragraph BYTE "THIS IS A TYPING TEST! PLEASE TYPE ALL THESE WORDS TO DETERMINE YOUR TYPING SPEED. THANK YOU, AND HAVE A GREAT REST OF YOUR DAY!", 0
	dictionary BYTE "ALPHABET", 0, "BANANA", 0, "CREAM", 0, "DRAGON", 0, "ELEPHANT", 0, "FUCK", 0, "GEORGIA", 0, "HAMBURGER", 0, "IGUANA",0, "JAGUAR",0, "KANGAROO",0, "LOSER", 0, "MICHAELMANSOUR",0, "NEVERTHELESS", 0, "OCTOPUS" 
			   BYTE 0, "PENELOPE", 0, "QUERY", 0, "RENDEZVOUS", 0, "SATANIC", 0, "TROMBONE", 0, "UMBRELLA", 0, "VENEZUELA", 0, "WATERLOO", 0, "XYLOPHONE", 0, "YUGOSLAVIA", 0, "ZEBRA", 0
	wordSizes BYTE 9, 7, 6, 7, 9, 5, 8, 10, 7, 7, 9, 6, 15, 13, 8, 9, 6, 11, 8, 9, 9, 10, 9, 10, 11, 6
	horizontalPositionList BYTE 43, 12, 29, 68, 5, 39, 55, 17, 62, 24, 3, 49, 33, 60, 7, 19, 50, 2, 45, 36, 16, 58, 9, 27, 69, 34          ;column position
	verticalPositionList SBYTE 0, -1, -2, -3, -4, -5, -6, -7, -8, -9, -10, -11, -12, -13, -14, -15, -16, -17, -18, -19, -20, -21, -22, -23, -24, -25			;vertical position

	;current word and position attributes being affected
	displayedWord DWORD ?
	horizontalPosition DWORD ?     ;column position
	verticalPosition DWORD ?	;vertical position

	;overall score to be returned once the player loses
	score BYTE 0
	numIterations DWORD 0

	;inputLoopCounter 
	inputLoopCounter BYTE 0

	;current buffer of user input
	bufferSize BYTE 0
	arrayPositionPointer DWORD 0
	nextExpectedPositonPointer DWORD 0
	bufferHorizontalPositionPointer DWORD 0
	bufferVerticalPositionPointer DWORD 0

	;array to hold boundary line & opening prompt
	boundaryLine BYTE "------------------------------------------------------------------------------------------------------------------------", 0
	prompt BYTE "HI! :) TYPE (1) TO PLAY FALLING TYPING TUTOR, AND TYPE (2) TO PLAY TYPING SPEED TEST: ", 0
	promptOver BYTE "GAME OVER! Your score was ", 0
	wordsPerMinuteString BYTE "words per minute", 0
	buffer BYTE 1000 DUP(0)
.code 

dropWord PROC ;--------------------------------------------------------------------------------------------
	;ESI HOLDS THE OFFSET OF THE STRING TO BE WRITTEN
	;EBX HOLDS THE OFFSET OF horizontalPosition
	;EAX HOLDS THE OFFSET OF verticalPosition
	;dl holds horizontal position, dh holds vertical position
	;dh and verticalPosition has incremented by 1, and the word is printed to the screen
	;word is printed if the height is less than 25 and greater than 0 (signed arithmetic), and carry flag is cleared
	;game ends if the height is greater than 25 (signed), and the carry flag is set

	inc BYTE PTR [eax] ;increment the vertical position in memory
	TEST BYTE PTR [eax], 10000000b
	jnz outCond ;it is less than 0, so it is not printed to the screen
	
	;move the appropriate values for position into dl and dh registers
	mov dl, BYTE PTR [ebx]
	mov dh, BYTE PTR [eax]

	call gotoXY ;move the cursor to the appropriate position
	;print the string to the screen
	mov edx, esi
	call writeString
	
	;if the arrayPositionPointer
	cmp esi, arrayPositionPointer
	jne dontWriteWithGreen ;if they are equal, then we are on the currently writtenWord, so write over it in GREEN
		mov dl, BYTE PTR [ebx]
		mov dh, BYTE PTR [eax]
		call gotoXY ;move the cursor to the appropriate position
		xchg esi, eax
		;write the current buffer in green, then reset the textcolor back to white
		mov eax, green + (black* 16)
		call setTextColor
		mov edx, OFFSET buffer
		call writeString
		mov eax, white + (black* 16)
		call setTextColor
		xchg eax, esi
	dontWriteWithGreen:

	rightBeforeGameEndCond:
	;compare the height to 25 to determine if the user loses
	cmp BYTE PTR [eax], 25
	jge elseCond
		;it is less than 25
		clc
	jmp outCond
	elseCond:
		;it is greater than 25
		stc
	outCond:
	ret
dropWord ENDP ;--------------------------------------------------------------------------------------------

createBoundaryLine PROC ;--------------------------------------------------------------------------------------------
	;EDX HOLDS ADDRESS OF string that holds the line
	;EAX WILL BE OVERRIDDEN WITH color of boundary "red"

	;mov to desired position (0, 25)
	mov dl, 0
	mov dh, 25
	call Gotoxy

	mov eax, red+(black*16)
	mov edx, OFFSET boundaryLine
	call setTextColor
	call WriteString

	;reset the colors to default
	mov eax, white+(black*16)
	call setTextColor
	ret
createBoundaryLine ENDP ;--------------------------------------------------------------------------------------------

writeBufferToScreen PROC ;--------------------------------------------------------------------------------------------
	;mov to desired position (0, 0)
	mov dl, 0
	mov dh, 0
	call Gotoxy
	mov eax, green+(black*16)
	call setTextColor
	mov edx, OFFSET buffer
	call WriteString
	mov eax, white+(black*16)
	call setTextColor
	ret
writeBufferToScreen ENDP ;--------------------------------------------------------------------------------------------

appendToBuffer PROC ;--------------------------------------------------------------------------------------------
	mov dl, al
	mov eax, OFFSET buffer
	movzx ebx, bufferSize
	add eax, ebx
	mov BYTE PTR [eax], dl
	inc bufferSize
	inc eax
	mov BYTE PTR [eax], 0
	ret
appendToBuffer ENDP ;--------------------------------------------------------------------------------------------

clearBuffer PROC ;--------------------------------------------------------------------------------------------
	;RESET ALL BUFFER MEMORY ELEMENTS
	mov buffer, 0
	mov bufferSize, 0
	mov arrayPositionPointer, 0
	mov nextExpectedPositonPointer, 0
	mov bufferHorizontalPositionPointer, 0
	mov bufferVerticalPositionPointer, 0
	ret
clearBuffer ENDP ;--------------------------------------------------------------------------------------------

incrementPositions PROC ;--------------------------------------------------------------------------------------------
	inc horizontalPosition
	inc verticalPosition

	;eax holds the index of where we are in wordSizes, so that we know how many bytes to jump
	mov ebx, LENGTHOF wordSizes
	sub ebx, ecx
	movzx ebx, wordSizes[ebx]
	add displayedWord, ebx
	ret
incrementPositions ENDP ;--------------------------------------------------------------------------------------------

;mov esi, OFFSET dictionary BEFORE CALL TO THIS FUNCTION
inputLadder PROC ;--------------------------------------------------------------------------------------------
	call readKey ;al will hold the currently read-in key (ascii byte)
	jz noKeyPressed ;if any key was pressed from the readKey macro
		cmp arrayPositionPointer, 0
		jne lockedIn  ;we are not locked onto a target already
			mov ch, al
			call appendToBuffer
			mov al, ch
			mov ch, 0
			;linearly search in memory until we find a value that matches, and set the buffer variables appropriately
			mov ecx, LENGTHOF wordSizes
			mov ebx, OFFSET horizontalPositionList
			mov edx, OFFSET verticalPositionList

			mov displayedWord, esi
			mov horizontalPosition, ebx
			mov verticalPosition, edx
			linearSearchLoop:
				mov esi, displayedWord
				cmp al, BYTE PTR [esi]
				je linearSearchBreak
				call incrementPositions
				loop linearSearchLoop
			linearSearchBreak:
			;IT MUST NOT REACH THE END OF THE LOOP (AKA: ECX == 0) NOR MUST THE CHARACTER NOT BE ON THE SCREEN (AKA: THE VERTICAL POSITION MUST BE >= 0)
			cmp ecx, 0
			je notFound
			mov esi, verticalPosition
			cmp BYTE PTR [esi], 0
			jge foundLabel
				notFound:
				call clearBuffer
				jmp outCond
			foundLabel:
			mov esi, displayedWord
			mov arrayPositionPointer, esi
			inc esi
			mov nextExpectedPositonPointer, esi

			mov esi, horizontalPosition
			mov bufferHorizontalPositionPointer, esi
			mov dl, BYTE PTR [esi]

			mov esi, verticalPosition
			mov bufferVerticalPositionPointer, esi
			mov dh, BYTE PTR [esi]

			;linear searching complete
			;write over the word in GREEN
			call gotoxy
			mov edx, OFFSET buffer
			mov eax, green+(black*16)
			call writeString
			jmp outCond
		lockedIn:	  ;we are locked onto a target
			mov esi, nextExpectedPositonPointer
			cmp al, BYTE PTR [esi]
			je keyReadIsEqual ;key read in is not equal to the expected key, so dont append to the buffer
				
				;move to correct position
				mov esi, bufferHorizontalPositionPointer
				mov dl, BYTE PTR [esi]
				mov esi, bufferVerticalPositionPointer
				mov dh, BYTE PTR [esi]
				call gotoxy
				;print in green
				mov edx, OFFSET buffer
				mov eax, green+(black*16)
				call setTextColor
				call writeString

				jmp outCond
			keyReadIsEqual: ;key read in is EQUAL, so append it to the buffer and write over the word in GREEN
				call appendToBuffer
				inc nextExpectedPositonPointer

				;move to correct position
				mov esi, bufferHorizontalPositionPointer
				mov dl, BYTE PTR [esi]
				mov esi, bufferVerticalPositionPointer
				mov dh, BYTE PTR [esi]
				call gotoxy
				;print in green
				mov edx, OFFSET buffer
				mov eax, green+(black*16)
				call setTextColor
				call writeString

				jmp outCond
	noKeyPressed:	;if no key was pressed from the readKey macro
	outCond:
		mov eax, white+(black*16)
		;COMPARE THE BUFFER THE STRING (IF THEY MATCH, RESET THE VERTICAL POSITION IN MEMORY AND RESET THE BUFFER/BUFFERSIZE/ARRAYPOSITIONPOINTER/BUFFERVERTICAL&HORIZONTALPOSITIONPOINTERS/nextExpectedPositonPointer)
		call setTextColor
	ret
inputLadder ENDP ;--------------------------------------------------------------------------------------------
	
playTypingTutorFalling PROC ;--------------------------------------------------------------------------------------------
	mov score, 0
	mainLoop:
		;clear the screen
		call clrscr

		mov ecx, LENGTHOF wordSizes
		mov esi, OFFSET dictionary
		mov ebx, OFFSET horizontalPositionList
		mov eax, OFFSET verticalPositionList

		mov displayedWord, esi
		mov horizontalPosition, ebx
		mov verticalPosition, eax

		;drop (every) word -- will be looped
		innerLoop1:
		mov esi, displayedWord
		mov ebx, horizontalPosition
		mov eax, verticalPosition
		call dropWord
		jc gameOver
		call incrementPositions
			loop innerLoop1

		call createBoundaryLine

		;delay & input loop
		mov inputLoopCounter, 90
		movzx ecx, inputLoopCounter
		bufferLoop:
			mov eax, 10
			call delay
			mov esi, OFFSET dictionary
			call inputLadder
			dec inputLoopCounter
			movzx ecx, inputLoopCounter

			;COMPARE THE STRINGS, AND IF THE WORD IS FINISHED MOVE IT BACK UP!!!
			mov eax, arrayPositionPointer
			cmp eax, 0
			je notMoveBackToTop
			INVOKE Str_compare, eax, OFFSET buffer
			jne notMoveBackToTop
				mov eax, bufferVerticalPositionPointer
				mov BYTE PTR [eax], -26
				call clearBuffer
				inc score
				jmp mainLoop
			notMoveBackToTop:
			loop bufferLoop
		jmp mainLoop

	gameOver: 
		call clrscr
		mov edx, OFFSET promptOver
		call writeString
		movzx eax, score
		call writeDec
	ret
playTypingTutorFalling ENDP ;--------------------------------------------------------------------------------------------

calculateWordsPerMin PROC  ;--------------------------------------------------------------------------------------------
	;numIterations is the divisor while 249F0 is the dividend
	mov edx, 0
	mov eax, 100000
	DIV numIterations
	;now eax holds the rate the user types words (wpn)
	ret
calculateWordsPerMin ENDP  ;--------------------------------------------------------------------------------------------

playTypingTest PROC  ;--------------------------------------------------------------------------------------------
	call clrscr
	mov dl, 0
	mov dh, 0
	call gotoxY
	mov edx, OFFSET paragraph
	call writeString
	mainLoop:
		inc numIterations
		call writeBufferToScreen
		mov eax, 10 
		call delay
		call readKey
		cmp arrayPositionPointer, 0
		je notLockedIn ; we are locked onto the target and able to continue to the next word
			;if the read in key does not equal the value pointed to by nextPositionPointer, then ignore it. Otherwise, append it to the buffer
			mov esi, nextExpectedPositonPointer
			cmp BYTE PTR [esi], 0
			je testOver
			cmp al, BYTE PTR [esi]
			jne outCond ;it is the expected, so append it to the buffer and 
				call appendToBuffer
				inc nextExpectedPositonPointer
		notLockedIn: ;we are not locked onto the target and still expecting the first word
			;if the read in key does not equal the first word in the paragraph, then ignore it. Otherwise, append it to the buffer
			mov esi, OFFSET paragraph
			mov bl, BYTE PTR [esi]
			cmp al, bl
			jne notEqual ;the keys match, so append it to the buffer
				call appendToBuffer
				mov arrayPositionPointer, esi
				inc esi
				mov nextExpectedPositonPointer, esi
			notEqual: ;the keys dont match, so just move on
		outCond:
		jmp mainLoop

	testOver:
		call clrscr
		mov edx, OFFSET promptOver
		call writeString
		call calculateWordsPerMin ;eax now holds the number of words per min
		call writeDec
		mov edx, OFFSET wordsPerMinuteString
		call writeString
	ret
playTypingTest ENDP  ;--------------------------------------------------------------------------------------------

main PROC ;--------------------------------------------------------------------------------------------
	;Initial MENU SCREEN
	mov edx, OFFSET prompt
	call writeString
	call readInt
	
	cmp eax, 1
	je typingTutorLabel
		call playTypingTest
		jmp programEndLabel
	typingTutorLabel:
		call playTypingTutorFalling
	programEndLabel:
	INVOKE ExitProcess, 0
main ENDP ;--------------------------------------------------------------------------------------------
END main
