;**
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
;**
;                                                                     *
;    Filename:	    Terreneitor.asm                                   *
;    Date:	    16/06/2025                                        *
;    File Version:  Final                                             *
;                                                                     *
;    Author: Luca Baccino                                             *
;    Company:  -                                                      *
;                                                                     *
;                                                                     *
;**
;                                                                     *
;    Files Required: P16F887.INC                                      *
;                                                                     *
;**
;                                                                     *
;    Notes:  -                                                        *
;                                                                     *
;**


	list		p=16f887	; list directive to define processor
	#include	<p16f887.inc>	; processor specific variable definitions


; '__CONFIG' directive is used to embed configuration data within .asm file.
; The labels following the directive are located in the respective .inc file.
; See respective data sheet for additional information on configuration word.

	__CONFIG    _CONFIG1, _LVP_OFF & _FCMEN_ON & _IESO_OFF & _BOR_OFF & _CPD_OFF & _CP_OFF & _MCLRE_ON & _PWRTE_ON & _WDT_OFF & _INTRC_OSC_NOCLKOUT
	__CONFIG    _CONFIG2, 0x3EFF

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
ESTADO_MOVIMIENTO   EQU 0x7A
DISTANCIA_BLOQUEO   EQU 0x7B

#DEFINE	TRIGGER	PORTA,3
#DEFINE	ECHO	PORTA,4
   
DISTANCIA_UMBRAL EQU 0x7D ; Valor leído por el ADC (distancia min)
	
;**

	ORG 0x00		  ; processor reset vector
	GOTO CONF
	
	ORG 0x04
	GOTO ISR
	
TABLA
    ADDWF   PCL,1
    RETLW   0x3F ; 0
    RETLW   0x06 ; 1
    RETLW   0x5B ; 2
    RETLW   0x4F ; 3
    RETLW   0x66 ; 4
    RETLW   0x6D ; 5
    RETLW   0x7D ; 6
    RETLW   0x07 ; 7
    RETLW   0x7F ; 8
    RETLW   0x6F ; 9
	
CONF
    BANKSEL ANSEL
    CLRF    ANSEL   ; seleccion puertos digitales y analogicos
    CLRF    ANSELH
    
    ; Configurar RE0 como entrada
    BANKSEL TRISE
    BSF     TRISE, 0        ; RE0 como entrada

    ; Habilitar AN5 (RE0) como canal analógico
    BANKSEL ANSEL
    BSF     ANSEL, 5        ; AN5 habilitado

    BANKSEL PORTE
    CLRF    PORTE
    
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
    CLRF    TRISD   ; PUERTO D DISPLAY
    CLRF    TRISB
    BSF	    TRISB, 2 ; RB2 --> INPUT
    BSF	    TRISB, 3 ; RB3 --> INPUT
    BSF	    TRISB, 5 ; RB5 --> INPUT
    
    BANKSEL RCSTA
    MOVLW   b'10010000'	; configuracion del USART para recepcion continua
    MOVWF   RCSTA		; puesta en ON
    
    BANKSEL OPTION_REG	; configuracion timer 0
    MOVLW   B'00000000'
    MOVWF   OPTION_REG
    
    BANKSEL ADCON0
    MOVLW   b'00010101'    ; Canal AN5, ADC encendido
    MOVWF   ADCON0

    BANKSEL ADCON1
    MOVLW   b'00000000'   
    MOVWF   ADCON1
    
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
    CLRF    ESTADO_MOVIMIENTO
    CLRF    DATO_RX
    MOVLW   'S'
    MOVWF   ESTADO_MOVIMIENTO
    
START 
    BCF	    PIR1, RCIF
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
    MOVF    DISTANCIA_BLOQUEO, 0
    BTFSC   STATUS, Z
    CALL    RESTAURAR_MOVIMIENTO
    GOTO    START ; vuelvo a iniciar una medicion
    
ISR ; rutina de interrupcion
    BTFSC   PIR1,RCIF	; Interrupcion por recepcion?
    GOTO    RECEPCION  ; Si --> voy a decodificar dato recibido
    BTFSS   INTCON,2	; Interrupcion por tmr0?
    GOTO    FINALIZAR	; No --> termina ISR
    MOVLW   TMR0_CARGA58  ; mientras el echo sea 0 las interrupciones estaran 
    MOVWF   TMR0          ; habilitadas y se repetira la recarga de tmr0 hasta
    INCF    VAR_DISTANCIA ; que se termine la medicion
    BCF	    INTCON,2
    RETFIE
    
RECEPCION
    CALL    DELAY5MS
    CALL    DELAY5MS
    MOVF    RCREG,W		; Leo el dato recibido
    MOVWF   DATO_RX
    MOVWF   ESTADO_MOVIMIENTO
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
    
RESTAURAR_MOVIMIENTO
    MOVF    ESTADO_MOVIMIENTO, W
    CALL    DECODIFICACION
    RETURN
    
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
    CALL    LECTURA_ADC
    MOVF    DISTANCIA_UMBRAL, W
    SUBLW   .99
    BTFSS   STATUS,C
    CALL    OVERFLOW
    MOVF    VAR_DISTANCIA, W
    SUBWF   DISTANCIA_UMBRAL, W ; W = VAR_DISTANCIA - DISTANCIA_UMBRAL
    BTFSC   STATUS,C
    GOTO    BLOQUEO_ACTIVO     ; si la medicion es menor que X enciendo una advertencia
    CLRF    DISTANCIA_BLOQUEO
    GOTO    SIGUE_MUESTREO
    
BLOQUEO_ACTIVO
    MOVLW   .1
    MOVWF   DISTANCIA_BLOQUEO
    CALL    STOP
    
SIGUE_MUESTREO
    MOVF    DISTANCIA_UMBRAL,0
    CALL    binario_a_bcd ; convierto el valor de la distancia para mostrar por los displays
    MOVF    bcd_unidad,0
    CALL    TABLA
    MOVWF   DISPLAY2
    MOVF    bcd_decena,0
    CALL    TABLA
    MOVWF   DISPLAY1
    MOVF    .50
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
    
    ; Lectura por polling del botón en RB0 (activo a nivel bajo)
    BTFSS   PORTB, 2        ; ¿Está presionado? (RB2 == 0)
    GOTO    BOTON_POLL
    BTFSS   PORTB, 3        ; ¿Está presionado? (RB3 == 0)
    GOTO    BOTON_POLL
    BTFSS   PORTB, 5        ; ¿Está presionado? (RB4 == 0)
    GOTO    BOTON_POLL
    GOTO    CONTINUAR

BOTON_POLL
    CALL    DELAY5MS        ; Antirrebote
    CALL    DELAY5MS
    CALL    DELAY5MS
    CALL    DELAY5MS
    BTFSS   PORTB, 2        ; Verifico si sigue presionado
    GOTO    BOTON_ACCION    ; Sí, ejecuto acción
    BTFSS   PORTB, 3
    GOTO    BOTON_IZQ
    BTFSS   PORTB, 5
    GOTO    BOTON_DER
    GOTO    CONTINUAR       ; No, fue un rebote
    
BOTON_IZQ
    CALL    IZQUIERDA            ; Izquierda
    MOVLW   'I'
    MOVWF   ESTADO_MOVIMIENTO
    MOVWF   DATO_RX
    GOTO    CONTINUAR
    
BOTON_DER
    CALL    DERECHA            ; Detengo motores
    MOVLW   'D'
    MOVWF   ESTADO_MOVIMIENTO
    MOVWF   DATO_RX
    GOTO    CONTINUAR

BOTON_ACCION
    CALL    STOP            ; Detengo motores
    MOVLW   'S'
    MOVWF   ESTADO_MOVIMIENTO
    MOVWF   DATO_RX

CONTINUAR
    RETURN
    
LECTURA_ADC
    BANKSEL ADCON0
    BSF     ADCON0, GO     ; Iniciar conversión
ADC_WAIT
    BTFSC   ADCON0, GO
    GOTO    ADC_WAIT       ; Esperar hasta que termine
    MOVF    ADRESH, W
    MOVWF   DISTANCIA_UMBRAL
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
    NOP
    NOP
    NOP
    NOP
    NOP
    RETURN
    
OVERFLOW
    MOVLW   .99
    MOVWF   DISTANCIA_UMBRAL
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
    BSF	PORTA,6
    RETURN
    
DERECHA
    BCF	PORTA,0
    BCF	PORTA,1
    BCF	PORTA,6
    BCF	PORTA,7
    BSF	PORTA,0
    RETURN
    
STOP
    BCF	PORTA,0
    BCF	PORTA,1
    BCF	PORTA,6
    BCF	PORTA,7
    RETURN
    
	
    END
