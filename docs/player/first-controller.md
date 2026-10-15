# Your first computer-to-inserter controller

This small factory uses only a computer and logic handler. The complete
[logic-controller program](examples.md#logic-controller) is the source to paste.

## Build

1. [Research and craft](getting-started.md) one computer and one logic handler.
   Power both. For a north-facing logic handler, the three ports are INPUT,
   NETWORK and OUTPUT from left to right.
2. Place a supply chest with iron plates, an inserter and a destination chest.
   Aim the inserter from supply to destination and power it. Use a separate
   stock-reading chest so you can change the controller's input independently.
3. In the stock chest's normal circuit controls, enable **Read contents**. Connect
   it to logic **INPUT red**. Put five normal-quality iron plates in this chest.
4. Connect computer **NETWORK red** directly to logic **NETWORK red**. An optional
   KV NETWORK port can relay this path; a vanilla power pole cannot.
5. Connect logic **OUTPUT green** to the inserter. In the inserter's native GUI,
   enable circuit-controlled enable/disable with **virtual signal A > 0**.
   The handler emits the same bank on red and green; green here is just convenient
   separation from the stock input. Do not wire INPUT to OUTPUT unintentionally.

    Stock chest --red--> INPUT [LOGIC] NETWORK <--red-- COMPUTER NETWORK
                              OUTPUT --green--> Inserter

## Enter and run

Select the computer and use its normal open action or the rebindable
**Ctrl+Shift+E** editor action. Copy the whole `return { ... }` document from
[logic-controller](examples.md#logic-controller), not the repository's outer
`return [[...]]` host wrapper. Use **Validate**, **Save**, then **Run**.
Use buttons while the source text box has focus; do not depend on shortcuts
being delivered from a native text field.

The program subscribes to normal-quality iron plate input. Below 100 plates it
writes A=1; at 100 or above it empties its bank. Increase/decrease the reading
chest's contents and watch the inserter after native circuit propagation and any
in-flight item settle. Different quality items are separate identities.

**Refresh Peripherals** should show a `logic_handler` on red. The program retains
stock/sample/change information in explicit computer state. There is no direct
computer-to-computer message API.

## Prove Save is not Apply

Change the threshold in the source from 100 to 3, then Save without Apply. At
stock=5, the old running revision still enables the inserter. Apply the saved
revision and it now stops. Status distinguishes draft base, saved and active
revisions. Invalid candidate validation leaves the old run alive.

Press **Stop** or disconnect the red NETWORK path. The handler clears this run's
still-owned output through host cleanup, even if the program fails. Another
computer's later successful write owns the entire bank and is not cleared by the
older computer stopping. Stop does not erase state, KV or display contents.

## If it does not move

- Check inserter direction, supply, destination capacity, electricity and its A>0
  condition. A wire alone does not enable circuit-controlled operation.
- Confirm the chest is reading contents into INPUT, not NETWORK.
- Check all discovery links use red NETWORK ports. INPUT selection and discovery
  color are different choices.
- Read the diagnostic pane; a fault needs wiring/source repair and explicit Run.
  Do not raise limits or busy-loop on pending errors.

Continue with the [combined controller](factory.md), which configures the inserter
for you and adds a database and monitor. Native client typing, focus and visual
wire interaction are still alpha checks for the player, not headless guarantees.
