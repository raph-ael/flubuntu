/* Flubuntu — minimal Calamares slideshow. */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#2c001e"
        }
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: "Willkommen bei Flubuntu\n\nUbuntu 26.04 — snap-frei.\nFirefox als deb, Thunderbird als Flatpak,\nApp-Center via GNOME Software."
            color: "#ffffff"
            font.pixelSize: 22
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#2c001e"
        }
        Text {
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            text: "Kein snapd. Kein App-Store-Zwang.\n\nEin sichtbares, schwebendes Dock\nund reine deb/Flatpak-Pakete."
            color: "#ffffff"
            font.pixelSize: 22
        }
    }

    function onActivate() {}
    function onLeave() {}
}
