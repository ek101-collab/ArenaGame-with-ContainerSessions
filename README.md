# Arena Game Multiplayer
Dieses Projekt ist im Rahmen einer Vorlesung an meiner Hochschule entstanden. Dabei handelt es sich um ein Multiplayer-Arena-Game, das vom Grundprinzip her an das bekannte Spiel Super Smash Bros. erinnert, allerdings in einer deutlich vereinfachten Form. Dabei sollten moderne Entwicklungsprinzipien und -techniken berücksichtigt werden, wie das Hosten von Anwendungen auf cloudbasierten Plattformen, die Ausarbeitung von Netzwerkarchitekturen sowie der Umgang mit Containern (z. B. Docker) und deren Deployment.

**Frontend:** https://46.101.127.20.sslip.io/ (online bis 31. März 2026) (**Tipp: Falls das Frontend beim Host- oder Join-Vorgang nach mehreren Runden Fehler erzeugt, am besten den Browsercache leeren oder das Spiel immer im Inkognitomodus des Browsers starten.**)

## Spielprinzip

Zu Beginn eines Spiels werden alle teilnehmenden Spieler zufällig in der Arena positioniert. Ab diesem Moment können sie sich frei bewegen und andere Spieler angreifen. Zusätzlich verfügt jeder Spieler über eine Dash-Funktion, mit der schnelle Ausweichbewegungen möglich sind.

Das Ziel des Spiels ist es, gegnerische Spieler gegen die Wände der Arena zu schlagen. Bei jedem Treffer erhöht sich der Knockback-Wert des getroffenen Spielers. Je höher dieser Wert ist, desto stärker fällt der Rückstoß bei weiteren Treffern aus.

Jeder Treffer erhöht den Knockback um **20 Prozent**. Der aktuelle Wert wird über dem jeweiligen Spieler angezeigt und kann maximal **110 Prozent** erreichen. Wird ein Spieler mit einem hohen Knockback-Wert getroffen, wird er entsprechend stark zurückgestoßen, was die Kontrolle innerhalb der Arena deutlich erschwert.

Berührt ein Spieler die Wand der Arena, scheidet er aus dem Spiel aus. Sobald nur noch ein Spieler übrig ist, endet das Match. Der Gewinner wird auf dem Bildschirm angezeigt und anschließend werden alle Spieler zurück ins Hauptmenü geleitet.

## Spiel erstellen

Um ein Spiel zu erstellen, muss im Frontend zunächst ein **Name eingegeben** und anschließend auf den **Host**-Button geklickt werden. Nach einer kurzen Ladezeit wird der Spieler **automatisch** in die Lobby weitergeleitet. Dort kann der Host das Spiel starten.

**Es wird empfohlen, das Spiel nicht alleine zu starten, da es sonst zu Problemen mit der Gewinnbedingung kommen kann. Mindestens zwei Spieler sollten an einer Runde teilnehmen. Außerdem sollte der Host-Button nur einmal gedrückt werden. Das Frontend leitet den Host automatisch weiter, sobald die Lobby bereit ist.**

**Zusätzlich können die Entwicklertools des jeweiligen Browsers genutzt werden, um nachzuvollziehen, was während des Spielaufbaus im Hintergrund passiert. Dafür müssen die Entwicklertools geöffnet und in das Console-Fenster gewechselt werden, in dem entsprechende kurze Logs angezeigt werden.**

## Spiel beitreten

Sobald ein Spiel erstellt wurde und der Host in die Lobby weitergeleitet wurde, wird dort ganz oben ein Beitrittscode angezeigt. Mit diesem Code können weitere Spieler dem Spiel beitreten.

Spieler, die beitreten möchten, **müssen** im Frontend ebenfalls einen **Namen** eingeben. **Anstatt den Host-Button** zu verwenden, tragen sie den **Beitrittscode** in das **dafür vorgesehene Textfeld** ein und klicken anschließend **NUR** auf den **Join**-Button.

**Der Beitrittscode ist nicht case-sensitiv. Es spielt also keine Rolle, ob der Code in Groß- oder Kleinschreibung eingegeben wird.**

## Spielcontrols

**Bewegung:** WASD

**Dash:** Shift

**Angriff:** Space
