pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs

Singleton {
    id: root

    property var json: JSON.parse(mprisJsonFile.text())
    property var players: Mpris.players.values
    property var _connections: ({})
    property int bestPlayerIndex: players.reduce((best, player, i) => (best === -1 || (player.isPlaying && !players[best].isPlaying) || (player.isPlaying === players[best].isPlaying && priorityOrder.indexOf(player.identity) !== -1 && (priorityOrder.indexOf(player.identity) < priorityOrder.indexOf(players[best].identity) || priorityOrder.indexOf(players[best].identity) === -1))) ? i : best, -1)
    property list<string> prevPlayingPlayers: []

    readonly property list<string> priorityOrder: ["Spotify", "Fastpotify", "Mozilla zen"]
    readonly property bool isAnyPlaying: players.some(player => player.isPlaying)

    onPlayersChanged: updateConnections()
    Component.onCompleted: updateConnections()

    Connections {
        target: AudioService.sink?.audio ?? null
        function onMutedChanged() {
            if (AudioService.sink?.audio?.muted) {
                root.prevPlayingPlayers = [];
                root.players.map(p => {
                    if (p.canTogglePlaying && p.isPlaying) {
                        root.prevPlayingPlayers.push(p.identity);
                        p.isPlaying = false;
                    }
                });
            } else if (AudioService.sink?.audio?.muted === false) {
                root.players.map(p => {
                    if (p.canTogglePlaying && !p.isPlaying && root.prevPlayingPlayers.includes(p.identity))
                        p.isPlaying = true;
                });
                root.prevPlayingPlayers = [];
            }
        }
    }

    function updateConnections() {
        // Clean up old connections
        for (let key in _connections) {
            _connections[key].destroy();
        }
        _connections = {};

        // Create new connections for each player
        players.forEach(player => {
            const conn = connectionsComponent.createObject(root, {
                player: player
            });
            _connections[player.dbusName] = conn;
        });
    }

    function reprocessAll() {
        for (let key in _connections) {
            if (_connections[key]) {
                _connections[key].processTrack();
            }
        }
    }

    FileView {
        id: mprisJsonFile
        path: Paths.mprisFile
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }

    property Component connectionsComponent: Component {
        Connections {
            property var player
            target: player

            function onTrackChanged() {
                processTrack();
            }

            function onPositionChanged() {
                processTrack();
            }

            function processTrack() {
                const playerName = player.dbusName.replace("org.mpris.MediaPlayer2.", "");
                const artUrl = player.trackArtUrl;
                Quickshell.execDetached(["sh", "-c", `${Paths.mprisPlayersProcessorScript} "${playerName}" "${artUrl}"`]);
            }
        }
    }
}
