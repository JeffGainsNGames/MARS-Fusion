; Change the map screen to show the next sector instead of the current sector
; tank counts when the select button is pressed

.autoregion
    .align 2
.func CycleSectorMaps
    push    { r4, lr }
    cmp     r0, #0
    beq     @@cycle_sector
    ldr     r0, =CurrArea
    ldrb    r4, [r0]
    ldr     r1, =03000B85h
    mov     r0, #0
    strb    r0, [r1]
    ldr     r1, =0300163Ah
    b       @@reenable_loc_flash
@@cycle_sector:
    ldr     r2, =03001696h
    ldrb    r0, [r2]
    add     r0, #1
    sub     r1, r0, Area_NOC + 1
    asr     r1, #1Fh
    and     r0, r1
    strb    r0, [r2]
    mov     r4, r0
    ldr     r1, =MenuSprites + 12h * MenuSprite_Size
    lsl     r0, #1
    add     r0, #MenuSpriteGfx_MainDeckSignTurningOn
    strb    r0, [r1, MenuSprite_Graphic]
    ldr     r1, =CurrArea
    ldrb    r0, [r1]
    ldr     r1, =0300163Ah
    cmp     r0, r4
    beq     @@reenable_loc_flash
    mov     r0, #0
    b       @@set_loc_flash
@@reenable_loc_flash:
    mov     r0, #1
@@set_loc_flash:
    strb    r0, [r1]
    mov     r0, r4
    ldr     r1, =MinimapData
    bl      08077084h
    mov     r0, r4
    bl      0807576Ch
    ldr     r1, =DMA3
    ldr     r0, =MinimapData
    str     r0, [r1, DMA_SAD]
    ldr     r0, =0600E000h
    str     r0, [r1, DMA_DAD]
    ldr     r0, =80000400h
    str     r0, [r1, DMA_CNT]
    ldr     r0, [r1, DMA_CNT]
    mov     r0, #1
    bl      08075988h
    add     r1, =@@MapStartCoords
    lsl     r0, r4, #1
    add     r1, r0
    ldr     r2, =030016DCh
    ldr     r3, =BgPositions
    ldrb    r0, [r1]
    strb    r0, [r2]
    add     r0, #(200h >> 3) - 15
    lsl     r0, #3
    strh    r0, [r3, BgPositions_Bg3X]
    ldrb    r0, [r1, #1]
    strb    r0, [r2, #1]
    add     r0, #(200h >> 3) - 10
    lsl     r0, #3
    strh    r0, [r3, BgPositions_Bg3Y]
    pop     { r4, pc }
    .pool
    .align 4
@@MapStartCoords:
.if UNHIDDEN_MAP
    .db     13, 8
    .db     9, 6
    .db     8, 8
    .db     10, 6
    .db     10, 7
    .db     11, 6
    .db     7, 7
.else
    .db     13, 8
    .db     8, 4
    .db     5, 2
    .db     10, 6
    .db     10, 7
    .db     6, 5
    .db     7, 6
.endif
.endfunc
.endautoregion

.org 0807686Ch
.area 06h
    mov     r0, #1
    bl      CycleSectorMaps
.endarea

.org 08075720h
.area 14h
    mov     r0, #0
    bl      CycleSectorMaps
    b       0807572Ch
.endarea

.autoregion
    .align 2
.func ShouldShowArrows
    ; return a bool representing whether arrows should be shown in this sector,
    ; or -1 if they should not be shown at all in this sub-gamemode.
    push    { r4-r5 }
    ldr     r0, =NonGameplayFlag
    ldrb    r0, [r0]
    cmp     r0, #2
    bne     @@return_neg
    ; check if sector map has been downloaded
    ldr     r0, =SamusUpgrades
    ldrb    r0, [r0, SamusUpgrades_MapDownloads]
    ldr     r1, =03001696h
    ldrb    r1, [r1]
    lsr     r0, r1
    lsr     r0, #1
    bcs     @@return_true
    ; check if any minimap tiles are explored
    ldr     r4, =MinimapVisited
    lsl     r1, #07h
    add     r4, r1
    mov     r5, r4
    add     r5, #80h
@@loop:
    ldmia   r4!, { r0-r3 }
    orr     r0, r1
    orr     r2, r3
    orr     r0, r2
    bne     @@return_true
    cmp     r4, r5
    blt     @@loop
    mov     r0, #0
    b       @@return
@@return_true:
    mov     r0, #1
    b       @@return
@@return_neg:
    mov     r0, #0
    mvn     r0, r0
@@return:
    pop     { r4-r5 }
    bx      lr
    .pool
.endfunc
.endautoregion

.org 08077CFCh
.area 0Eh
    bl      ShouldShowArrows
    cmp     r0, #0
    beq     08077D14h
    bgt     08077D0Ah
    b       08077E38h
.endarea


; Add vanilla pause OAM Data to free space
.defineregion 0856F71Ch, 352Dh, 0

.autoregion
@PauseScreenObjGfx:
.incbin "data/pause-obj.gfx"
.endautoregion

.org PauseScreenGfxOamPointer
    .dw @PauseScreenObjGfx


; OAM Data Format
; See: https://problemkaputt.de/gbatek-lcd-obj-oam-attributes.htm for details
; .dh Number of objects
; .dh ObjAttr0
; .dh ObjAttr1
; .dh ObjAttr2
; ... Repeat for as many objects in the frame

.autoregion
    .aligna 4
@SelectMapChangeOamData:
    .dh 7
    ; Vanilla Objective (A)
    ;.dh 00F8h
    .dh (OBJ0_YCoordinate & 0F8h) | OBJ0_Mode_Normal | OBJ0_Shape_Square
    ;.dh 41DBh
    .dh (OBJ1_XCoordinate & 1DBh) | OBJ1_Size_16x16
    ;.dh 33AEh
    .dh (OBJ2_Character   & 3AEh) | OBJ2_Priority_Highest | ((OBJ2_PaletteMask & 03h) << OBJ2_Palette)

    ; Vanilla "OBJEC"
    .dh (OBJ0_YCoordinate & 0FCh) | OBJ0_Mode_Normal | OBJ0_Shape_Horizontal
    .dh (OBJ1_XCoordinate & 1E9h) | OBJ1_Size_32x8
    .dh (OBJ2_Character   & 3D0h) | OBJ2_Priority_Highest | ((OBJ2_PaletteMask & 03h) << OBJ2_Palette)

    ; Vanilla "TIVE"
    .dh (OBJ0_YCoordinate & 0FCh) | OBJ0_Mode_Normal | OBJ0_Shape_Horizontal
    .dh (OBJ1_XCoordinate & 009h) | OBJ1_Size_32x8
    .dh (OBJ2_Character   & 3D4h) | OBJ2_Priority_Highest | ((OBJ2_PaletteMask & 03h) << OBJ2_Palette)

    ; 2x2 Select Button Graphic
    ;.notice tohex((OBJ0_YCoordinate & 040h) | OBJ0_Mode_Normal | OBJ0_Shape_Square)
    .dh (OBJ0_YCoordinate & 07Ah) | OBJ0_Mode_Normal | OBJ0_Shape_Square
    .dh (OBJ1_XCoordinate & 13Ch) | OBJ1_Size_16x16
    .dh (OBJ2_Character   & 3BEh) | OBJ2_Priority_Highest | ((OBJ2_PaletteMask & 03h) << OBJ2_Palette)

    ;.notice tohex((OBJ0_YCoordinate & 080h) | OBJ0_Mode_Normal | OBJ0_Shape_Square)
    .dh (OBJ0_YCoordinate & 07Dh) | OBJ0_Mode_Normal | OBJ0_Shape_Horizontal
    .dh (OBJ1_XCoordinate & 144h) | OBJ1_Size_32x8
    .dh (OBJ2_Character   & 377h) | OBJ2_Priority_Highest | ((OBJ2_PaletteMask & 03h) << OBJ2_Palette)

    ;.notice tohex((OBJ0_YCoordinate & 0C0h) | OBJ0_Mode_Normal | OBJ0_Shape_Square)
    .dh (OBJ0_YCoordinate & 085h) | OBJ0_Mode_Normal | OBJ0_Shape_Horizontal
    .dh (OBJ1_XCoordinate & 138h) | OBJ1_Size_32x8
    .dh (OBJ2_Character   & 3B8h) | OBJ2_Priority_Highest | ((OBJ2_PaletteMask & 03h) << OBJ2_Palette)

    ;.notice tohex((OBJ0_YCoordinate & 0C0h) | OBJ0_Mode_Normal | OBJ0_Shape_Square)
    .dh (OBJ0_YCoordinate & 085h) | OBJ0_Mode_Normal | OBJ0_Shape_Horizontal
    .dh (OBJ1_XCoordinate & 158h) | OBJ1_Size_16x8
    .dh (OBJ2_Character   & 3BCh) | OBJ2_Priority_Highest | ((OBJ2_PaletteMask & 03h) << OBJ2_Palette)

.endautoregion

; OAM Data Pointer Format
; .dw Pointer, Timer (in frames, specify 0FFh for no animation)
; repeat above for each frame
; .dd 0 ; mark end with null DWORD
.autoregion
    .aligna 4
@SelectChangeMapOamDataPointers:
    .dw @SelectMapChangeOamData
    .dw 0FFh
    .dd 0
.endautoregion

; Pointer to OAM Data Pointers
.org PauseScreenOamData + (PauseScreenOamData_ObjectiveButton * 4)
    .dw @SelectChangeMapOamDataPointers

.autoregion
    .align 2
.func ShowMapChangeOam
    push    {lr}
    pop     {r0}
    pop     {r3,r4,r5}
    mov     r8,r3
    mov     r9,r4
    mov     r10,r5
    pop     {r4,r5,r6,r7}
    bx      r0
.endfunc
.endautoregion


.org 080780E0h
.area 0Fh

    bl ShowMapChangeOam

    ;pop     {r3,r4,r5}
    ;mov     r8,r3
    ;mov     r9,r4
    ;mov     r10,r5
    ;pop     {r4,r5,r6,r7}

    pop     {r0}
    bx      r0

.endarea
