
[MapROM]: Programs/MapROM.md
[FastRAM]: Programs/FastRAM.md
[BlitFix]: Programs/BlitFix.md



# TFTools
*Atari utilities for TerribleFire accelerator cards.*

---

**Programs: ⸢ [MapROM] ⸥ ⸢ [FastRAM] ⸥ ⸢ [BlitFix] ⸥**

---

### Supported Cards

- **TF534**
- **TF536**

Other accelerators should also work as long as:
- **FastRAM** is located in **TT-RAM** space (`0x01000000`)
- The **CPU** is of type `68030` with a **MMU**

---

### Code

Parts of the programs:
- are based on the **EmuTOS** teams work
- use `COOKIE.s` by **Arnd Beissner**

The programs can be compiled with **Devpac 3**
