. For the selection stuff, there's 3 main things to track that I could tell off hand which were abilities, spells and mounts. Trusts are considered spells, Weapon Skills are abilities.

For the menu names:
Abilities: menu    ability 
   Spells: menu    magic   
   Mounts: menu    mount   

The menus are listboxes in memory, but have some specialized handling for abilities/spells since those can be heavily filtered and reordered. Mounts are straight forward.

Then outside of that you would just want to track which kind of menu is open (if any) before doing any calls to reduce overhead.