[MapROM]: /MapROM.md


# BlitFix

This program fixes **Blitter** issues for **TT-RAM** machines.

*Still allows programs and* ***TOS*** *to use* ***Blitter***


---

### Support

- **TOS 2.06 / 3.06**
- **EmuTOS**
- Limited use on other **TOS**

---

**This program must be run after [MapROM]**

---

### Inactive

This program does not activate unless the machine has:
- Available **TT-RAM**
- A **32 bit CPU**
- **Blitter** installed

🠒 It is safe to leave the program in your `AUTO` folder.

---

### What It Does

<br>

##### NVDI / WARP9

**Prevents crashes** by tricking these programs<br>
into thinking that **Blitter** is not present.

<br>

##### Atari TOS 2.06 / 3.06

**Patches** `VDI` / `LineA` **Blitter** routines to use software<br>
routines with address ranges outside of **Blitter** ranges.

<br>

##### EmuTOS

Allows **ST-RAM** to know **Blitters** real status instead<br>
of having it hidden while **TT-RAM** is present.

**BlitFix** stays dormant if you use a <br>
custom **EmuTOS** that do show **Blitter**

<br>

##### Other TOS

- TOS is made to believe that **Blitter** is not present.

- Only programs running in **ST-RAM** will be told that **Blitter** is present.
