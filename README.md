# DFA
A simple script that applies damage to players based on calculated forces from acceleration/deceleration.

## Hooks
- DFA_PlayerDamage (provides Player and Damage) (accepts Pass and Amount)
	- Called whenever a player is about to be damaged by this script
	- Returning false will stop the damage outright, otherwise returning true will allow it, and optionally the overridden damage as the second input

## CVars
- dfa_glimit (number G-force limit)
	- The threshold of Gs a player can withstand before taking damage

- dfa_damagemult (number Amount to multiply damage by)
	- Multiplies the damage (before being affected by the override hook) a player will receive from G-force damage

This script will also respect updates to sv_gravity, and adjust damage/limits accordingly.

This should also support simphys and other vehicle mods with funky offset seat positions.

## Issues
Please report any issues under the Issues tab!