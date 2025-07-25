# Reading HOTS replays

```julia true false true
@__DIR__
```
```julia true false true
]activate .; add CondaPkg PythonCall; 
```
```julia true false true
using CondaPkg, PythonCall
CondaPkg.add_pip("heroprotocol")
heroprotocol = pyimport("heroprotocol")
```
```python true false true
import heroprotocol
import sys
import os

def extract_hots_player_names_with_heroprotocol(replay_path):
    """
    Extract player names from Heroes of the Storm replay using heroprotocol library.
    """
    try:
        # Load the replay
        archive = heroprotocol.mpyq.MPQArchive(replay_path)
        
        # Get the header and details
        header = heroprotocol.versions.latest().decode_replay_header(archive.header['user_data_header']['content'])
        details = heroprotocol.versions.latest().decode_replay_details(archive.read_file('replay.details'))
        
        # Extract player names
        player_names = []
        
        if 'm_playerList' in details:
            for player in details['m_playerList']:
                if 'm_name' in player:
                    name = player['m_name'].decode('utf-8')
                    player_names.append(name)
        
        return player_names
        
    except Exception as e:
        print(f"Error with heroprotocol: {e}")
        return []

# Test with your replay file
replay_path = "/sim/Documents/Heroes of the Storm/Accounts/447744432/2-Hero-1-10071754/Replays/Multiplayer/2025-07-14 20.59.40 Braxis Holdout.StormReplay"

print(f"Extracting player names using heroprotocol...")
player_names = extract_hots_player_names_with_heroprotocol(replay_path)

if player_names:
    print(f"\n🎮 Found {len(player_names)} players:")
    for i, name in enumerate(player_names, 1):
        print(f"{i}. {name}")
else:
    print("No player names found or library not available.")
```
```python true false true
replay_path = "/sim/Documents/Heroes of the Storm/Accounts/447744432/2-Hero-1-10071754/Replays/Multiplayer/2025-07-14 20.59.40 Braxis Holdout.StormReplay"
extract_hots_player_names_with_heroprotocol(replay_path)
```
```python true false true
import heroprotocol
import os

# Test with your replay file
replay_path = "/sim/Documents/Heroes of the Storm/Accounts/447744432/2-Hero-1-10071754/Replays/Multiplayer/2025-07-14 20.59.40 Braxis Holdout.StormReplay"

# Load the replay archive
archive = heroprotocol.archive.load_archive(replay_path)

# Get protocol based on the replay
protocol = heroprotocol.protocol.get_protocol(archive)

print(f"Protocol version: {protocol}")

# Extract player details
details = protocol.decode_replay_details(archive.read_file('replay.details'))

print(f"Details loaded successfully")

# Extract player names
player_names = []

if 'm_playerList' in details:
    print(f"Found {len(details['m_playerList'])} players in m_playerList")
    
    for i, player in enumerate(details['m_playerList']):
        print(f"Player {i+1}: {player}")
        
        # Try different fields where the name might be stored
        name = None
        
        # Common fields for player names
        name_fields = ['m_name', 'm_playerName', 'm_battleTag', 'm_displayName']
        
        for field in name_fields:
            if field in player and player[field]:
                name = player[field]
                if isinstance(name, bytes):
                    name = name.decode('utf-8', errors='ignore')
                print(f"   Found name in {field}: {name}")
                break
        
        if name:
            player_names.append(name)
        else:
            print(f"   No name found for player {i+1}")

else:
    print("No m_playerList found in details")
    print("Available keys in details:", list(details.keys()))

print(f"\nFINAL RESULT: {len(player_names)} player names extracted")
for i, name in enumerate(player_names, 1):
    print(f"{i}. {name}")

player_names
```
