;************************
;   This file is a basic code template for assembly code generation   *
;   on the PIC16F887. This file contains the basic code               *
;   building blocks to build upon.                                    *
;                                                                     *
;   Refer to the MPASM User's Guide for additional information on     *
;   features of the assembler (Document DS33014).                     *
;                                                                     *
;   Refer to the respective PIC data sheet for additional             *
;   information on the instruction set.                               *
;                                                                     *
;************************
;                                                                     *
;    Filename:	    Terreneitor.asm                                   *
;    Date:	    XX/XX/2025                                        *
;    File Version:  Final                                             *
;                                                                     *
;    Author: Luca Baccino                                             *
;    Company:  -                                                      *
;                                                                     *
;                                                                     *
;************************
;                                                                     *
;    Files Required: P16F887.INC                                      *
;                                                                     *
;************************
;                                                                     *
;    Notes:  -                                                        *
;                                                                     *
;************************


    PROCESSOR 16F887
    #include <xc.inc>	; processor specific variable definitions


; '__CONFIG' directive is used to embed configuration data within .asm file.
; The labels following the directive are located in the respective .inc file.
; See respective data sheet for additional information on configuration word.

	__CONFIG    _CONFIG1, _LVP_OFF & _FCMEN_ON & _IESO_OFF & _BOR_OFF & _CPD_OFF & _CP_OFF & _MCLRE_ON & _PWRTE_ON & _WDT_OFF & _INTRC_OSC_NOCLKOUT
	__CONFIG    _CONFIG2, _WRT_OFF & _BOR21V

bcd_unidad  EQU 0x70
bcd_decena  EQU 0x71
bcd_centena EQU	0x78
DISPLAY1    EQU 0x72
DISPLAY2    EQU	0x73
CONT0	    EQU 0x74	
CONTADOR1   EQU	0x75
CONTADOR2   EQU	0x76
CONTADOR3   EQU	0x79
VAR_DISTANCIA	EQU 0x77
DATO_RX	    EQU	0x30
DIST_MIN    EQU .2
DIST_MAX    EQU .99
TMR0_CARGA58 EQU .220 ; cargar con 256-58

#DEFINE	TRIGGER	PORTA,3
#DEFINE	ECHO	PORTA,4
	
;************************

	ORG 0x00		  ; processor reset vector
	GOTO CONF
	
	ORG 0x04
	GOTO ISR
	
TABLA
    ADDWF	PCL,1
    RETLW	0xFE ; cero
    RETLW	0x30 ; uno
    RETLW	0x6D ; dos
    RETLW	0xF9 ; tres
    RETLW	0x33 ; cuatro
    RETLW	0x5B ; cinco
    RETLW	0x1F ; seis
    RETLW	0xF0 ; siete
    RETLW	0xFF ; ocho
    RETLW	0xF3 ; nueve
	
CONF
    BANKSEL ANSEL
    CLRF    ANSEL   ; seleccion puertos digitales y analogicos
    CLRF    ANSELH
    
    BANKSEL TRISA
    MOVLW   b'10110000'	; RC7/RX entrada
    MOVWF   TRISC	; RC6/TX salida
			; Y PARA MULTIPLEXAR DISPLAYS
    MOVLW   b'00100100'	; configuracion USART
    MOVWF   TXSTA	; y activacion de transmision
    MOVLW   .25		; 9600 Baudios
    MOVWF   SPBRG
    BSF	    PIE1,RCIE	; Habilita interrupcion en recepcion
    CLRF    TRISA
    BCF	    TRISA,3 ; TRIGGER = SALIDA
    BSF	    TRISA,4 ; ECHO = ENTRADA
    CLRF    TRISC   ; PUERTO C SALIDA MULTIPLEXAR
    CLRF    TRISD   ; PUERTO D DISPLAY
    
    BANKSEL RCSTA
    MOVLW   b'10010000'	; configuracion del USART para recepcion continua
    MOVWF   RCSTA		; puesta en ON
    
    BANKSEL OPTION_REG	; configuracion timer 0
    MOVLW   B'00000000'
    MOVWF   OPTION_REG
    
    MOVLW   b'11000000'	; Habilitacion de las interrupciones en general
    MOVWF   INTCON
    
    BANKSEL PORTC   ; limpio registros que voy a utilizar
    BCF	    TRIGGER ; APAGO TRIGGER
    CLRF    PORTA
    CLRF    PORTB
    CLRF    PORTC
    CLRF    PORTD
    CLRF    W
    CLRF    CONT0
	
START 
    CLRF    VAR_DISTANCIA ; limpio el registro donde gruardo la distancia
    BSF	    TRIGGER
    CALL    DELAY_10_MICROS
    BCF	    TRIGGER ; enciendo el trigger durante 10us (visto en datasheet)

ECHO_ES_1
    BTFSS   ECHO    ; si echo es uno se sigue midiendo al distancia
    GOTO    ECHO_ES_1 ; bucle para cuando echo es 0
    MOVLW   TMR0_CARGA58 ; cargo tmr0 para 58us (segun datasheet)
    MOVWF   TMR0
    BSF	    INTCON,5	; Habilito interrupcion por timer 0
    
ECHO_ES_0
    BTFSC   ECHO ; si echo es 0 ya termino la medicion de distancia
    GOTO    ECHO_ES_0 ; bule para cuando echo es 1
    BCF	    INTCON,5 ; Detengo interrupciones por timer 0
    CALL    MUESTRA_DISPLAY ; voy a mostrar en el display la distancia medida
    GOTO    START ; vuelvo a iniciar una medicion
    
ISR ; rutina de interrupcion
    BTFSC   PIR1,RCIF	; Interrupcio por recepcion?
    GOTO    RECEPCION  ; Si --> voy a decodificar dato recibido
    BTFSS   INTCON,2	; Interrupcion por tmr0?
    GOTO    FINALIZAR	; No --> termina ISR
    MOVLW   TMR0_CARGA58  ; mientras el echo sea 0 las interrupciones estaran 
    MOVWF   TMR0          ; habilitadas y se repetira la recarga de tmr0 hasta
    INCF    VAR_DISTANCIA ; que se termine la medicion
    BCF	    INTCON,2
    RETFIE
    
RECEPCION
    MOVF    RCREG,W		; Leo el dato recibido
    MOVWF   DATO_RX
    CALL    DECODIFICACION
    MOVLW   'A'
    MOVWF   TXREG
    BCF	    PIR1,RCIF	; Limpio bandera
    CALL    DELAY5MS
    CALL    DELAY5MS
    CALL    DELAY5MS
    CALL    DELAY5MS
FINALIZAR
    RETFIE
    
DECODIFICACION
    MOVF    DATO_RX,W
    XORLW   'A'	    ; El dato recibido es Adelante?
    BTFSC   STATUS,Z
    GOTO    ADELANTE
	
    MOVF    DATO_RX,W
    XORLW   'R'	    ; El dato recibido es Retroceder?
    BTFSC   STATUS,Z
    GOTO    RETROCEDER
	
    MOVF    DATO_RX,W
    XORLW   'D'	    ; El dato recibido es Derecha?
    BTFSC   STATUS,Z
    GOTO    DERECHA
	
    MOVF    DATO_RX,W
    XORLW   'I'	    ; El dato recibido es Izquierda?
    BTFSC   STATUS,Z
    GOTO    IZQUIERDA
    
    MOVF    DATO_RX,W
    XORLW   'S'	    ; El dato recibido es Stop?
    BTFSC   STATUS,Z
    GOTO    STOP
	
    RETURN
    
    ; Un motor esta conectado a A0 y A1
    ; El otro esta conectado a A6 y A7
    
MUESTRA_DISPLAY
    MOVF    VAR_DISTANCIA,0
    SUBLW   .99
    BTFSS   STATUS,C
    CALL    OVERFLOW
    MOVF    VAR_DISTANCIA,0
    SUBLW   .10 ; comparo mi medicion con 10cm
    BTFSC   STATUS,C
    CALL    STOP     ; si la medicion es menor que 15 enciendo una advertencia
    MOVF    VAR_DISTANCIA,0
    CALL    binario_a_bcd ; convierto el valor de la distancia para mostrar por los displays
    MOVF    bcd_unidad,0
    CALL    TABLA
    MOVWF   DISPLAY1
    MOVF    bcd_decena,0
    CALL    TABLA
    MOVWF   DISPLAY2
    MOVLW   .40
    MOVWF   CONTADOR3 ; contador para retrasar un poco el tiempo entre mediciones

LOOP			
    BSF	    PORTC,3 ; rutina para multiplexar displays
    MOVF    DISPLAY1,0
    MOVWF   PORTD
    CALL    DELAY5MS
    BCF	    PORTC,3
    BSF	    PORTC,2
    MOVF    DISPLAY2,0
    MOVWF   PORTD
    CALL    DELAY5MS
    BCF	    PORTC,2
    DECFSZ  CONTADOR3
    GOTO    LOOP
    RETURN
    
DELAY5MS
    MOVLW   .12 ; cargar con 12 aprox para delay de 5ms
    MOVWF   CONTADOR1
D_LOOP
    MOVLW   .250
    MOVWF   CONTADOR2
    DECFSZ  CONTADOR2
    GOTO    $-1
    DECFSZ  CONTADOR1
    GOTO    D_LOOP
    RETURN
    
binario_a_bcd
    MOVWF   bcd_unidad ; Carga el número binario a convertir
    CLRF    bcd_centena ; Borra registro
    CLRF    bcd_decena ; Borra registro
    
BCD_Resta10
    MOVLW   .10 ; A las unidades de les va restando
    SUBWF   bcd_unidad,0 ; 10 en cada pasada
    BTFSS   STATUS,C ;C=0? si- entonces bcd_unidad>=0
    GOTO    BIN_BCD_Fin ; No- entonces se acabo    
    
BCD_IncrementarDecenas
    MOVWF   bcd_unidad ; Recupera lo que queda por restar
    INCF    bcd_decena,1 ; Incrementa las decenas
    MOVLW   .10
    SUBWF   bcd_decena,0 ; Comprueba si a llegado a 10
    BTFSS   STATUS,C ;C=1? si- entonces bcd_decena>=0
    GOTO    BCD_Resta10 ; No- entonces resta 10 a las unidades
    
BCD_IncrementarCentenas
    CLRF    bcd_decena ; Pone a cero las decenas
    INCF    bcd_centena,1 ; Incrementa las centenas
    GOTO    BCD_Resta10 ; Resta 10 al número a convertir
    
BIN_BCD_Fin
    SWAPF   bcd_decena,0 ; Intercambia nibles
    ADDWF   bcd_unidad,0 ; Nible bajo=unidades / Nible alto=decenas
    RETURN
    
DELAY_10_MICROS
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    RETURN
    
OVERFLOW
    MOVLW   .99
    MOVWF   VAR_DISTANCIA
    RETURN
    
ADELANTE
    BCF	PORTA,0
    BCF	PORTA,1
    BCF	PORTA,6
    BCF	PORTA,7
    BSF	PORTA,1
    BSF	PORTA,7
    RETURN
    
RETROCEDER
    BCF	PORTA,0
    BCF	PORTA,1
    BCF	PORTA,6
    BCF	PORTA,7
    BSF	PORTA,0
    BSF	PORTA,6
    RETURN
    
IZQUIERDA
    BCF	PORTA,0
    BCF	PORTA,1
    BCF	PORTA,6
    BCF	PORTA,7
    BSF	PORTA,0
    RETURN
    
DERECHA
    BCF	PORTA,0
    BCF	PORTA,1
    BCF	PORTA,6
    BCF	PORTA,7
    BSF	PORTA,6
    RETURN
    
STOP
    BCF	PORTA,0
    BCF	PORTA,1
    BCF	PORTA,6
    BCF	PORTA,7
    RETURN
    
	
    END
