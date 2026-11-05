# Your first computer-to-inserter controller

This small factory uses only a computer and logic handler. The complete
[logic-controller program](examples.md#logic-controller) is the source to paste.

## Build

1. [Research and craft](getting-started.md) one computer and one logic handler.
   Neither needs electricity. A north-facing logic handler has three ports: INPUT,
   NETWORK and OUTPUT, from left to right.
2. Place a supply chest with iron plates, an inserter and a destination chest.
   Aim the inserter from supply to destination. Supply electricity to the inserter. Use a separate
   stock-reading chest so you can change the controller's input independently.
3. In the stock chest's normal circuit controls, enable **Read contents**. Connect
   it to logic **INPUT red**. Put five normal-quality iron plates in this chest.
4. Connect computer **NETWORK red** directly to logic **NETWORK red**. An optional
   KV device can relay this path. A vanilla power pole cannot.
5. Connect logic **OUTPUT green** to the inserter. In the inserter's native GUI,
   enable circuit-controlled enable/disable with **virtual signal A > 0**.
   The handler emits the same bank on red and green. Here, green separates
   the output from the stock input. Do not accidentally wire INPUT to OUTPUT.

    Stock chest --red--> INPUT [LOGIC] NETWORK <--red-- COMPUTER NETWORK
                              OUTPUT --green--> Inserter

## Enter and run

Clear the cursor. **Ctrl + left-click the computer** to open its workspace.
Ordinary clicks remain available for wiring. Copy the complete function declarations from
[logic-controller](examples.md#logic-controller). Do not copy the repository's outer
`return [[...]]` host wrapper. Select **Validate**. Select **Save**. Then select **Run**.
Use buttons while the source text box has focus. Do not depend on shortcuts
being delivered from a native text field.

The program subscribes to normal-quality iron plate input. Below 100 plates, it
writes A=1. At 100 or above, it empties its bank. Increase or decrease the reading
chest's contents. Wait for native circuit propagation and for any item in transit to settle.
Then examine the inserter. Items of different qualities have separate identities.

The automatically updating **Peripherals** tab should show a `logic_handler` on red. The program retains
stock/sample/change information in explicit computer state. There is no direct
computer-to-computer message API.

## Prove Save is not Apply

Change the threshold in the source from 100 to 3. Select Save without Apply. At
stock=5, the old active revision still enables the inserter. Apply the saved
revision. The inserter now stops. Status distinguishes the draft base, saved and active
revisions. If candidate validation fails, the old run continues.

Press **Stop** or disconnect the red NETWORK path. The handler clears this run's
still-owned output through host cleanup, even if the program fails. Another
computer's later successful write owns the entire bank. Stopping the older computer does not clear that bank. Stop does not erase state, KV or display contents.

## If it does not move

- Check inserter direction, supply, destination capacity, electricity and its A>0
  condition. A wire alone does not enable circuit-controlled operation.
- Confirm the chest is reading contents into INPUT, not NETWORK.
- Check all discovery links use red NETWORK ports. INPUT selection and discovery
  color are different choices.
- Read the diagnostic pane. After a fault, repair the wiring or source. Then select Run.
  Do not raise limits or busy-loop on pending errors.

Continue with the [combined controller](factory.md), which configures the inserter
for you and adds a database and monitor. Players must still check native client typing, focus and visual
wire interaction in this alpha. Headless tests do not guarantee these behaviors.
