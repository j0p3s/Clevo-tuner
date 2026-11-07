<# :
@echo off
setlocal
title ClevoTune
set "CT_SELF=%~f0"
set "CT_ARGS=%*"
fltmc >nul 2>&1 && goto :run
powershell -NoProfile -ExecutionPolicy Bypass -Command "$a=@{FilePath=$env:CT_SELF;Verb='RunAs'}; if($env:CT_ARGS){$a.ArgumentList=$env:CT_ARGS}; Start-Process @a"
exit /b
:run
powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command "iex ([IO.File]::ReadAllText($env:CT_SELF))"
exit /b
#>
# ClevoTune - monitor, GPU tuning and EC fan curves for Clevo P775DM3-G (i7-8700K + RTX 3080)
# https://github.com/j0p3s/Clevo-tuner
$ErrorActionPreference = 'Stop'
$AppName    = 'ClevoTune'
$AppVersion = '1.6.3'

$Self = $env:CT_SELF
if (-not $Self) { $Self = $PSCommandPath }
$SelfDir   = Split-Path -Parent $Self
$TrayStart = ("$env:CT_ARGS" -match '(?i)(^|\s)[/-]tray')

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms, System.Drawing, Microsoft.VisualBasic

# ---------------------------------------------------------------- languages (key = English text)
$LangTable = @'
The card still enforces {0} W: on this GPU the power limit can be lowered, but not raised above {1} W. The slider maximum is now {1} W.	A placa continua a aplicar {0} W: nesta GPU o limite de potência pode ser baixado, mas não subir acima de {1} W. O máximo do slider passa a ser {1} W.	La carte applique toujours {0} W : sur ce GPU la limite de puissance peut être abaissée, mais pas relevée au-dessus de {1} W. Le maximum du curseur est maintenant {1} W.	La tarjeta sigue aplicando {0} W: en esta GPU el límite de potencia puede bajarse, pero no subir por encima de {1} W. El máximo del control pasa a ser {1} W.	Die Karte erzwingt weiterhin {0} W: Auf dieser GPU kann das Leistungslimit gesenkt, aber nicht über {1} W angehoben werden. Das Reglermaximum ist jetzt {1} W.	La scheda applica ancora {0} W: su questa GPU il limite di potenza può essere abbassato, ma non alzato oltre {1} W. Il massimo del cursore ora è {1} W.
Check for mVolt+ updates	Procurar atualizações do mVolt+	Rechercher des mises à jour de mVolt+	Buscar actualizaciones de mVolt+	Nach mVolt+-Updates suchen	Cerca aggiornamenti di mVolt+
Checking mVolt+ updates…	A procurar atualizações do mVolt+…	Recherche de mises à jour de mVolt+…	Buscando actualizaciones de mVolt+…	Suche nach mVolt+-Updates…	Ricerca aggiornamenti di mVolt+…
mVolt+ is up to date ({0})	O mVolt+ está atualizado ({0})	mVolt+ est à jour ({0})	mVolt+ está actualizado ({0})	mVolt+ ist aktuell ({0})	mVolt+ è aggiornato ({0})
mVolt+ updated: {0} → {1}	mVolt+ atualizado: {0} → {1}	mVolt+ mis à jour : {0} → {1}	mVolt+ actualizado: {0} → {1}	mVolt+ aktualisiert: {0} → {1}	mVolt+ aggiornato: {0} → {1}
mVolt+ update check failed: {0}	Falha ao procurar atualizações do mVolt+: {0}	Échec de la recherche de mises à jour de mVolt+ : {0}	Falló la búsqueda de actualizaciones de mVolt+: {0}	Suche nach mVolt+-Updates fehlgeschlagen: {0}	Ricerca aggiornamenti di mVolt+ non riuscita: {0}
mVolt+ update will be installed next start (file in use)	A atualização do mVolt+ será instalada no próximo arranque (ficheiro em uso)	La mise à jour de mVolt+ sera installée au prochain démarrage (fichier utilisé)	La actualización de mVolt+ se instalará en el próximo inicio (archivo en uso)	Das mVolt+-Update wird beim nächsten Start installiert (Datei in Verwendung)	L'aggiornamento di mVolt+ verrà installato al prossimo avvio (file in uso)
mVolt+ {0} — {1}	mVolt+ {0} — {1}	mVolt+ {0} — {1}	mVolt+ {0} — {1}	mVolt+ {0} — {1}	mVolt+ {0} — {1}
mVolt+ (by b00nz) is kept in a mVolt+ folder next to ClevoTune and updated automatically from its GitHub releases (checked at most every 12 hours). ClevoTune runs it through its command line for the power limit when the NVIDIA driver blocks it, and for the core voltage offset.	O mVolt+ (de b00nz) fica numa pasta mVolt+ ao lado do ClevoTune e é atualizado automaticamente a partir das releases no GitHub (verificado no máximo a cada 12 horas). O ClevoTune usa-o pela linha de comandos para o limite de potência quando o driver da NVIDIA o bloqueia, e para o offset de tensão do núcleo.	mVolt+ (de b00nz) est conservé dans un dossier mVolt+ à côté de ClevoTune et mis à jour automatiquement depuis ses versions GitHub (vérifié au plus toutes les 12 heures). ClevoTune l'utilise en ligne de commande pour la limite de puissance quand le pilote NVIDIA la bloque, et pour le décalage de tension du cœur.	mVolt+ (de b00nz) se guarda en una carpeta mVolt+ junto a ClevoTune y se actualiza automáticamente desde sus versiones de GitHub (comprobado como máximo cada 12 horas). ClevoTune lo usa por línea de comandos para el límite de potencia cuando el driver de NVIDIA lo bloquea, y para el offset de voltaje del núcleo.	mVolt+ (von b00nz) liegt in einem Ordner mVolt+ neben ClevoTune und wird automatisch über die GitHub-Releases aktualisiert (höchstens alle 12 Stunden geprüft). ClevoTune nutzt es über die Kommandozeile für das Leistungslimit, wenn der NVIDIA-Treiber es sperrt, und für den Kernspannungs-Offset.	mVolt+ (di b00nz) è conservato in una cartella mVolt+ accanto a ClevoTune e aggiornato automaticamente dalle release su GitHub (controllo al massimo ogni 12 ore). ClevoTune lo usa da riga di comando per il limite di potenza quando il driver NVIDIA lo blocca, e per l'offset di tensione del core.
The power limit is locked on this GPU: NVML, NVAPI and mVolt+ all refused it, so the slider was disabled.	O limite de potência está bloqueado nesta GPU: o NVML, o NVAPI e o mVolt+ recusaram-no, por isso o slider foi desativado.	La limite de puissance est verrouillée sur ce GPU : NVML, NVAPI et mVolt+ l'ont tous refusée, le curseur a donc été désactivé.	El límite de potencia está bloqueado en esta GPU: NVML, NVAPI y mVolt+ lo han rechazado, así que el control se ha desactivado.	Das Leistungslimit ist auf dieser GPU gesperrt: NVML, NVAPI und mVolt+ haben es abgelehnt, daher wurde der Regler deaktiviert.	Il limite di potenza è bloccato su questa GPU: NVML, NVAPI e mVolt+ lo hanno rifiutato, quindi il cursore è stato disattivato.
Core voltage offset (mVolt+)	Offset de tensão do núcleo (mVolt+)	Décalage de tension du cœur (mVolt+)	Offset de voltaje del núcleo (mVolt+)	Kernspannungs-Offset (mVolt+)	Offset tensione core (mVolt+)
requires mVolt+	requer o mVolt+	nécessite mVolt+	requiere mVolt+	erfordert mVolt+	richiede mVolt+
applied: {0} mV	aplicado: {0} mV	appliqué : {0} mV	aplicado: {0} mV	angewendet: {0} mV	applicato: {0} mV
{0} mV vs stock	{0} mV vs stock	{0} mV vs origine	{0} mV vs. de serie	{0} mV vs. Standard	{0} mV vs stock
voltage {0} mV	tensão {0} mV	tension {0} mV	voltaje {0} mV	Spannung {0} mV	tensione {0} mV
MVOLT+ (OPTIONAL)	MVOLT+ (OPCIONAL)	MVOLT+ (FACULTATIF)	MVOLT+ (OPCIONAL)	MVOLT+ (OPTIONAL)	MVOLT+ (FACOLTATIVO)
mVolt+ found: {0}	mVolt+ encontrado: {0}	mVolt+ trouvé : {0}	mVolt+ encontrado: {0}	mVolt+ gefunden: {0}	mVolt+ trovato: {0}
mVolt+ not found. It is used for power limits and voltage offsets that the NVIDIA driver blocks on this GPU.	mVolt+ não encontrado. É usado para limites de potência e offsets de tensão que o driver da NVIDIA bloqueia nesta GPU.	mVolt+ introuvable. Il sert aux limites de puissance et aux décalages de tension que le pilote NVIDIA bloque sur ce GPU.	mVolt+ no encontrado. Se usa para los límites de potencia y offsets de voltaje que el driver de NVIDIA bloquea en esta GPU.	mVolt+ nicht gefunden. Es wird für Leistungslimits und Spannungs-Offsets verwendet, die der NVIDIA-Treiber auf dieser GPU sperrt.	mVolt+ non trovato. Serve per i limiti di potenza e gli offset di tensione che il driver NVIDIA blocca su questa GPU.
Locate mVolt+…	Localizar mVolt+…	Localiser mVolt+…	Localizar mVolt+…	mVolt+ suchen…	Trova mVolt+…
Download mVolt+	Descarregar mVolt+	Télécharger mVolt+	Descargar mVolt+	mVolt+ herunterladen	Scarica mVolt+
mVolt+ website	Site do mVolt+	Site de mVolt+	Web de mVolt+	mVolt+-Website	Sito di mVolt+
ClevoTune runs mVolt+ (by b00nz) through its command line for the power limit when the NVIDIA driver blocks it, and for the core voltage offset. mVolt+ is searched next to ClevoTune, in a mVolt+ subfolder, Downloads, Desktop and its own install folder.	O ClevoTune usa o mVolt+ (de b00nz) pela linha de comandos para o limite de potência quando o driver da NVIDIA o bloqueia, e para o offset de tensão do núcleo. O mVolt+ é procurado ao lado do ClevoTune, numa subpasta mVolt+, em Transferências, no Ambiente de Trabalho e na sua própria pasta de instalação.	ClevoTune utilise mVolt+ (de b00nz) en ligne de commande pour la limite de puissance quand le pilote NVIDIA la bloque, et pour le décalage de tension du cœur. mVolt+ est recherché à côté de ClevoTune, dans un sous-dossier mVolt+, Téléchargements, Bureau et son propre dossier d'installation.	ClevoTune usa mVolt+ (de b00nz) por línea de comandos para el límite de potencia cuando el driver de NVIDIA lo bloquea, y para el offset de voltaje del núcleo. mVolt+ se busca junto a ClevoTune, en una subcarpeta mVolt+, Descargas, Escritorio y su propia carpeta de instalación.	ClevoTune nutzt mVolt+ (von b00nz) über die Kommandozeile für das Leistungslimit, wenn der NVIDIA-Treiber es sperrt, und für den Kernspannungs-Offset. mVolt+ wird neben ClevoTune, in einem Unterordner mVolt+, in Downloads, auf dem Desktop und im eigenen Installationsordner gesucht.	ClevoTune usa mVolt+ (di b00nz) da riga di comando per il limite di potenza quando il driver NVIDIA lo blocca, e per l'offset di tensione del core. mVolt+ viene cercato accanto a ClevoTune, in una sottocartella mVolt+, in Download, sul Desktop e nella sua cartella di installazione.
mVolt+: {0}	mVolt+: {0}	mVolt+ : {0}	mVolt+: {0}	mVolt+: {0}	mVolt+: {0}
mVolt+ did not respond in time	o mVolt+ não respondeu a tempo	mVolt+ n'a pas répondu à temps	mVolt+ no respondió a tiempo	mVolt+ hat nicht rechtzeitig geantwortet	mVolt+ non ha risposto in tempo
Downloading mVolt+…	A descarregar o mVolt+…	Téléchargement de mVolt+…	Descargando mVolt+…	mVolt+ wird heruntergeladen…	Download di mVolt+…
mVolt+ downloaded: {0}	mVolt+ descarregado: {0}	mVolt+ téléchargé : {0}	mVolt+ descargado: {0}	mVolt+ heruntergeladen: {0}	mVolt+ scaricato: {0}
mVolt+ download failed: {0}	Falha ao descarregar o mVolt+: {0}	Échec du téléchargement de mVolt+ : {0}	Falló la descarga de mVolt+: {0}	mVolt+-Download fehlgeschlagen: {0}	Download di mVolt+ non riuscito: {0}
mVolt+ (*.exe)|*.exe	mVolt+ (*.exe)|*.exe	mVolt+ (*.exe)|*.exe	mVolt+ (*.exe)|*.exe	mVolt+ (*.exe)|*.exe	mVolt+ (*.exe)|*.exe
The power limit is locked on this GPU (vBIOS/driver), so the slider was disabled. Use mVolt+ to change power limits.	O limite de potência está bloqueado nesta GPU (vBIOS/driver), por isso o slider foi desativado. Usa o mVolt+ para alterar limites de potência.	La limite de puissance est verrouillée sur ce GPU (vBIOS/pilote) : le curseur a été désactivé. Utilisez mVolt+ pour modifier les limites de puissance.	El límite de potencia está bloqueado en esta GPU (vBIOS/driver), así que el control se ha desactivado. Usa mVolt+ para cambiar los límites de potencia.	Das Leistungslimit ist auf dieser GPU gesperrt (vBIOS/Treiber), daher wurde der Regler deaktiviert. Verwende mVolt+, um Leistungslimits zu ändern.	Il limite di potenza è bloccato su questa GPU (vBIOS/driver), quindi il cursore è stato disattivato. Usa mVolt+ per modificare i limiti di potenza.
Administrator	Administrador	Administrateur	Administrador	Administrator	Amministratore
Auto-apply: —	Auto-aplicar: —	Application auto : —	Autoaplicar: —	Auto-Anwenden: —	Applicazione auto: —
GPU tuning	Afinação GPU	Réglage GPU	Ajuste GPU	GPU-Tuning	Regolazione GPU
TUNING	AFINAÇÃO	RÉGLAGE	AJUSTE	TUNING	REGOLAZIONE
Card values	Valores do cartão	Valeurs de la carte	Valores de la tarjeta	Kartenwerte	Valori della scheda
Power limit (TGP)	Limite de potência (TGP)	Limite de puissance (TGP)	Límite de potencia (TGP)	Leistungslimit (TGP)	Limite di potenza (TGP)
on card: —	no cartão: —	sur la carte : —	en la tarjeta: —	auf der Karte: —	sulla scheda: —
Core clock offset	Offset clock núcleo	Décalage fréquence cœur	Offset reloj núcleo	Kerntakt-Offset	Offset clock core
Memory clock offset	Offset clock memória	Décalage fréquence mémoire	Offset reloj memoria	Speichertakt-Offset	Offset clock memoria
Max clock limit	Limite de clock máx.	Limite fréq. max.	Límite de reloj máx.	Max. Taktlimit	Limite clock max.
applied: off	aplicado: desligado	appliqué : désactivé	aplicado: desactivado	angewendet: aus	applicato: disattivato
off	desligado	désactivé	desactivado	aus	disattivato
limits voltage via the V/F curve	limita tensão via curva V/F	limite la tension via la courbe V/F	limita el voltaje vía la curva V/F	begrenzt die Spannung über die V/F-Kurve	limita la tensione tramite la curva V/F
Undervolting on Ampere: a clock limit plus a positive core offset (e.g. 1800 MHz + 150) makes the GPU reach that clock at a lower voltage. Direct voltage control is still done in mVolt+.	Undervolt em Ampere: limite de clock + offset positivo no núcleo (ex.: 1800 MHz + 150) faz a GPU atingir esse clock com menos tensão. Tensão direta continua a ser no mVolt+.	Sous-voltage sur Ampere : une limite de fréquence + un décalage positif du cœur (ex. : 1800 MHz + 150) fait atteindre cette fréquence au GPU avec moins de tension. Le réglage direct de la tension reste dans mVolt+.	Undervolt en Ampere: un límite de reloj + un offset positivo del núcleo (p. ej., 1800 MHz + 150) hace que la GPU alcance ese reloj con menos voltaje. El control directo del voltaje sigue en mVolt+.	Undervolting bei Ampere: Taktlimit + positiver Kern-Offset (z. B. 1800 MHz + 150) lässt die GPU diesen Takt mit weniger Spannung erreichen. Direkte Spannungssteuerung weiterhin in mVolt+.	Undervolt su Ampere: limite di clock + offset positivo del core (es. 1800 MHz + 150) fa raggiungere quel clock alla GPU con meno tensione. Il controllo diretto della tensione resta in mVolt+.
Apply to GPU	Aplicar na GPU	Appliquer au GPU	Aplicar a la GPU	Auf GPU anwenden	Applica alla GPU
Reset to stock	Repor stock	Rétablir d'origine	Restablecer de serie	Auf Standard zurücksetzen	Ripristina stock
Refresh readback	Reler do cartão	Relire la carte	Releer la tarjeta	Von Karte neu lesen	Rileggi dalla scheda
PROFILES	PERFIS	PROFILS	PERFILES	PROFILE	PROFILI
Load	Carregar	Charger	Cargar	Laden	Carica
Save as…	Guardar como…	Enregistrer sous…	Guardar como…	Speichern unter…	Salva come…
Delete	Apagar	Supprimer	Eliminar	Löschen	Elimina
Apply the last profile on open	Aplicar o último perfil ao abrir	Appliquer le dernier profil à l'ouverture	Aplicar el último perfil al abrir	Letztes Profil beim Öffnen anwenden	Applica l'ultimo profilo all'apertura
Applies the most recently saved profile every time the app opens	Aplica o perfil guardado mais recentemente sempre que a app abre	Applique le profil enregistré le plus récemment à chaque ouverture	Aplica el perfil guardado más reciente cada vez que se abre la app	Wendet bei jedem Start das zuletzt gespeicherte Profil an	Applica il profilo salvato più di recente a ogni apertura
Starts in the tray, applies the last profile and controls the fans	Arranca no tabuleiro, aplica o último perfil e controla as ventoinhas	Démarre dans la zone de notification, applique le dernier profil et pilote les ventilateurs	Se inicia en la bandeja, aplica el último perfil y controla los ventiladores	Startet im Infobereich, wendet das letzte Profil an und steuert die Lüfter	Si avvia nell'area di notifica, applica l'ultimo profilo e controlla le ventole
Fans	Ventoinhas	Ventilateurs	Ventiladores	Lüfter	Ventole
FANS (EC)	VENTOINHAS (EC)	VENTILATEURS (EC)	VENTILADORES (EC)	LÜFTER (EC)	VENTOLE (EC)
Mode	Modo	Mode	Modo	Modus	Modalità
Automatic (EC)	Automático (EC)	Automatique (EC)	Automático (EC)	Automatisch (EC)	Automatico (EC)
Curve	Curva	Courbe	Curva	Kurve	Curva
Fixed	Fixo	Fixe	Fijo	Fest	Fisso
Sensor	Sensor	Capteur	Sensor	Sensor	Sensore
CPU temp	Temp. CPU	Temp. CPU	Temp. CPU	CPU-Temp.	Temp. CPU
GPU temp	Temp. GPU	Temp. GPU	Temp. GPU	GPU-Temp.	Temp. GPU
Max CPU/GPU temp	Temp. máx. CPU/GPU	Temp. max CPU/GPU	Temp. máx. CPU/GPU	Max. Temp. CPU/GPU	Temp. max CPU/GPU
CPU load	Carga CPU	Charge CPU	Carga CPU	CPU-Last	Carico CPU
GPU load	Carga GPU	Charge GPU	Carga GPU	GPU-Last	Carico GPU
Max CPU/GPU load	Carga máx. CPU/GPU	Charge max CPU/GPU	Carga máx. CPU/GPU	Max. Last CPU/GPU	Carico max CPU/GPU
Preset	Predefinição	Préréglage	Preajuste	Vorgabe	Preimpostazione
Quiet	Silenciosa	Silencieux	Silencioso	Leise	Silenzioso
Balanced	Equilibrada	Équilibré	Equilibrado	Ausgewogen	Bilanciato
Cool	Fresca	Frais	Fresco	Kühl	Fresco
Maximum	Máximo	Maximum	Máximo	Maximum	Massimo
Fixed speed	Velocidade fixa	Vitesse fixe	Velocidad fija	Feste Drehzahl	Velocità fissa
Temp. (°C)	Temp. (°C)	Temp. (°C)	Temp. (°C)	Temp. (°C)	Temp. (°C)
Load (%)	Carga (%)	Charge (%)	Carga (%)	Last (%)	Carico (%)
Fan (%)	Ventoinha (%)	Ventilateur (%)	Ventilador (%)	Lüfter (%)	Ventola (%)
+ Point	+ Ponto	+ Point	+ Punto	+ Punkt	+ Punto
Remove	Remover	Retirer	Quitar	Entfernen	Rimuovi
Fixed 40–85 °C grid (like ClevoFanControl)	Grelha fixa 40–85 °C (como o ClevoFanControl)	Grille fixe 40–85 °C (comme ClevoFanControl)	Rejilla fija 40–85 °C (como ClevoFanControl)	Festes Raster 40–85 °C (wie ClevoFanControl)	Griglia fissa 40–85 °C (come ClevoFanControl)
Import .cfg	Importar .cfg	Importer .cfg	Importar .cfg	.cfg importieren	Importa .cfg
Export .cfg	Exportar .cfg	Exporter .cfg	Exportar .cfg	.cfg exportieren	Esporta .cfg
Save curves	Guardar curvas	Enregistrer les courbes	Guardar curvas	Kurven speichern	Salva curve
BEHAVIOUR	COMPORTAMENTO	COMPORTEMENT	COMPORTAMIENTO	VERHALTEN	COMPORTAMENTO
Hysteresis	Histerese	Hystérésis	Histéresis	Hysterese	Isteresi
only slows down after dropping X (°C or % load)	só baixa depois de descer X (°C ou % de carga)	ne ralentit qu'après une baisse de X (°C ou % de charge)	solo baja tras descender X (°C o % de carga)	senkt erst nach einem Rückgang um X (°C oder % Last)	rallenta solo dopo un calo di X (°C o % di carico)
Max ramp-down	Descida máxima	Descente max.	Bajada máxima	Max. Absenkung	Discesa massima
smooths slowing down (speeding up is instant)	suaviza a descida (subidas são imediatas)	adoucit la descente (les hausses sont immédiates)	suaviza la bajada (las subidas son inmediatas)	glättet das Absenken (Erhöhen erfolgt sofort)	ammorbidisce la discesa (gli aumenti sono immediati)
Load smoothing	Suavizar carga	Lissage de la charge	Suavizar carga	Last glätten	Smussa carico
averages the load to ignore spikes (load curves)	média da carga, evita picos (curvas por carga)	moyenne de la charge, évite les pics (courbes par charge)	promedia la carga, evita picos (curvas por carga)	mittelt die Last, ignoriert Spitzen (Lastkurven)	media del carico, evita i picchi (curve per carico)
Safety temperature	Temperatura de segurança	Température de sécurité	Temperatura de seguridad	Sicherheitstemperatur	Temperatura di sicurezza
CPU or GPU above this → 100% (load curves too)	CPU ou GPU acima disto → 100% (também nas curvas por carga)	CPU ou GPU au-dessus → 100 % (aussi pour les courbes par charge)	CPU o GPU por encima → 100% (también en curvas por carga)	CPU oder GPU darüber → 100 % (auch bei Lastkurven)	CPU o GPU sopra questo valore → 100% (anche con le curve per carico)
Return all to EC (auto)	Devolver todas ao EC (auto)	Tout rendre à l'EC (auto)	Devolver todos al EC (auto)	Alle an EC zurückgeben (auto)	Restituisci tutte all'EC (auto)
Overlay	Overlay	Overlay	Overlay	Overlay	Overlay
ON-SCREEN OVERLAY	OVERLAY NO ECRÃ	OVERLAY À L'ÉCRAN	OVERLAY EN PANTALLA	BILDSCHIRM-OVERLAY	OVERLAY A SCHERMO
Show overlay (over windowed/borderless games)	Mostrar overlay (por cima de jogos em janela/sem bordas)	Afficher l'overlay (au-dessus des jeux en fenêtré/sans bordure)	Mostrar overlay (sobre juegos en ventana/sin bordes)	Overlay anzeigen (über Spielen im Fenster/rahmenlos)	Mostra overlay (sopra i giochi in finestra/senza bordi)
Position	Posição	Position	Posición	Position	Posizione
Top left	Canto superior esquerdo	En haut à gauche	Arriba a la izquierda	Oben links	In alto a sinistra
Top right	Canto superior direito	En haut à droite	Arriba a la derecha	Oben rechts	In alto a destra
Bottom left	Canto inferior esquerdo	En bas à gauche	Abajo a la izquierda	Unten links	In basso a sinistra
Bottom right	Canto inferior direito	En bas à droite	Abajo a la derecha	Unten rechts	In basso a destra
Font size	Tamanho da letra	Taille de police	Tamaño de letra	Schriftgröße	Dimensione carattere
Background opacity	Opacidade do fundo	Opacité du fond	Opacidad del fondo	Hintergrunddeckkraft	Opacità sfondo
Show	Mostrar	Afficher	Mostrar	Anzeigen	Mostra
CPU (temp/load/W)	CPU (temp/carga/W)	CPU (temp/charge/W)	CPU (temp/carga/W)	CPU (Temp/Last/W)	CPU (temp/carico/W)
GPU (temp/load/W)	GPU (temp/carga/W)	GPU (temp/charge/W)	GPU (temp/carga/W)	GPU (Temp/Last/W)	GPU (temp/carico/W)
GPU clocks	Clocks GPU	Fréquences GPU	Relojes GPU	GPU-Takte	Clock GPU
Not shown over exclusive fullscreen games — use borderless mode. Does not show FPS.	Não aparece por cima de jogos em ecrã inteiro exclusivo — usa modo sem bordas. Não mostra FPS.	N'apparaît pas au-dessus des jeux en plein écran exclusif — utilisez le mode sans bordure. N'affiche pas les FPS.	No aparece sobre juegos en pantalla completa exclusiva — usa modo sin bordes. No muestra FPS.	Nicht über Spielen im exklusiven Vollbild sichtbar — rahmenlosen Modus verwenden. Zeigt keine FPS.	Non appare sopra i giochi a schermo intero esclusivo — usa la modalità senza bordi. Non mostra gli FPS.
Settings	Definições	Paramètres	Ajustes	Einstellungen	Impostazioni
HARDWARE ACCESS (PawnIO)	ACESSO AO HARDWARE (PawnIO)	ACCÈS AU MATÉRIEL (PawnIO)	ACCESO AL HARDWARE (PawnIO)	HARDWAREZUGRIFF (PawnIO)	ACCESSO ALL'HARDWARE (PawnIO)
PawnIO website	Site do PawnIO	Site de PawnIO	Web de PawnIO	PawnIO-Website	Sito di PawnIO
Reinstall driver + modules	Reinstalar driver + módulos	Réinstaller pilote + modules	Reinstalar driver + módulos	Treiber + Module neu installieren	Reinstalla driver + moduli
Open modules folder	Abrir pasta dos módulos	Ouvrir le dossier des modules	Abrir carpeta de módulos	Modulordner öffnen	Apri cartella moduli
Reinitialise sensors	Reinicializar sensores	Réinitialiser les capteurs	Reiniciar sensores	Sensoren neu initialisieren	Reinizializza sensori
Everything is installed automatically on first launch: the official PawnIO driver (signature checked before installing) and the LpcACPIEC.bin (fans) and IntelMSR.bin (CPU) modules from the latest PawnIO.Modules release.	Tudo é instalado automaticamente no primeiro arranque: o driver PawnIO oficial (assinatura verificada antes de instalar) e os módulos LpcACPIEC.bin (ventoinhas) e IntelMSR.bin (CPU) da última release do PawnIO.Modules.	Tout est installé automatiquement au premier lancement : le pilote PawnIO officiel (signature vérifiée avant l'installation) et les modules LpcACPIEC.bin (ventilateurs) et IntelMSR.bin (CPU) de la dernière version de PawnIO.Modules.	Todo se instala automáticamente en el primer inicio: el driver oficial de PawnIO (firma verificada antes de instalar) y los módulos LpcACPIEC.bin (ventiladores) e IntelMSR.bin (CPU) de la última versión de PawnIO.Modules.	Beim ersten Start wird alles automatisch installiert: der offizielle PawnIO-Treiber (Signatur vor der Installation geprüft) und die Module LpcACPIEC.bin (Lüfter) und IntelMSR.bin (CPU) aus dem neuesten PawnIO.Modules-Release.	Tutto viene installato automaticamente al primo avvio: il driver PawnIO ufficiale (firma verificata prima dell'installazione) e i moduli LpcACPIEC.bin (ventole) e IntelMSR.bin (CPU) dall'ultima release di PawnIO.Modules.
APPLICATION	APLICAÇÃO	APPLICATION	APLICACIÓN	ANWENDUNG	APPLICAZIONE
Closing the window minimises to the tray (fans stay controlled)	Fechar a janela minimiza para o tabuleiro (ventoinhas continuam controladas)	Fermer la fenêtre la réduit dans la zone de notification (les ventilateurs restent pilotés)	Cerrar la ventana la minimiza a la bandeja (los ventiladores siguen controlados)	Schließen minimiert in den Infobereich (Lüfter bleiben gesteuert)	Chiudere la finestra la riduce nell'area di notifica (le ventole restano controllate)
Polling interval	Intervalo de leitura	Intervalle de lecture	Intervalo de lectura	Abfrageintervall	Intervallo di lettura
Language	Idioma	Langue	Idioma	Sprache	Lingua
Automatic (system)	Automático (sistema)	Automatique (système)	Automático (sistema)	Automatisch (System)	Automatico (sistema)
Starting…	A iniciar…	Démarrage…	Iniciando…	Wird gestartet…	Avvio…
Log ▴	Registo ▴	Journal ▴	Registro ▴	Protokoll ▴	Registro ▴
Log ▾	Registo ▾	Journal ▾	Registro ▾	Protokoll ▾	Registro ▾
Startup error:	Erro ao iniciar:	Erreur au démarrage :	Error al iniciar:	Fehler beim Start:	Errore all'avvio:
Failed to compile the core:	Falha a compilar o núcleo:	Échec de compilation du noyau :	Error al compilar el núcleo:	Kern konnte nicht kompiliert werden:	Compilazione del nucleo non riuscita:
Error saving settings: {0}	Erro a guardar configuração: {0}	Erreur d'enregistrement de la configuration : {0}	Error al guardar la configuración: {0}	Fehler beim Speichern der Einstellungen: {0}	Errore nel salvataggio della configurazione: {0}
PawnIO installer verified: {0}	Instalador PawnIO verificado: {0}	Installateur PawnIO vérifié : {0}	Instalador de PawnIO verificado: {0}	PawnIO-Installer geprüft: {0}	Installer PawnIO verificato: {0}
invalid installer signature ({0})	assinatura do instalador inválida ({0})	signature de l'installateur invalide ({0})	firma del instalador no válida ({0})	ungültige Installer-Signatur ({0})	firma dell'installer non valida ({0})
PawnIO driver installed	Driver PawnIO instalado	Pilote PawnIO installé	Driver de PawnIO instalado	PawnIO-Treiber installiert	Driver PawnIO installato
PawnIO driver installed — Windows requests a restart	Driver PawnIO instalado — o Windows pede reinício	Pilote PawnIO installé — Windows demande un redémarrage	Driver de PawnIO instalado — Windows pide reiniciar	PawnIO-Treiber installiert — Windows verlangt einen Neustart	Driver PawnIO installato — Windows richiede un riavvio
the PawnIO installer exited with code {0}	o instalador do PawnIO terminou com o código {0}	l'installateur PawnIO s'est terminé avec le code {0}	el instalador de PawnIO terminó con el código {0}	der PawnIO-Installer endete mit Code {0}	l'installer di PawnIO è terminato con il codice {0}
GitHub API unavailable ({0}), trying the releases page	API do GitHub indisponível ({0}), a tentar pela página de releases	API GitHub indisponible ({0}), essai via la page des versions	API de GitHub no disponible ({0}), probando con la página de versiones	GitHub-API nicht verfügbar ({0}), versuche die Release-Seite	API di GitHub non disponibile ({0}), provo dalla pagina delle release
could not find the modules .zip in the latest release	não encontrei o .zip dos módulos na release mais recente	zip des modules introuvable dans la dernière version	no se encontró el .zip de módulos en la última versión	Modul-.zip im neuesten Release nicht gefunden	zip dei moduli non trovato nell'ultima release
Module {0} installed ({1})	Módulo {0} instalado ({1})	Module {0} installé ({1})	Módulo {0} instalado ({1})	Modul {0} installiert ({1})	Modulo {0} installato ({1})
Module {0} not found in the zip ({1})	Módulo {0} não encontrado no zip ({1})	Module {0} introuvable dans le zip ({1})	Módulo {0} no encontrado en el zip ({1})	Modul {0} nicht im Zip gefunden ({1})	Modulo {0} non trovato nello zip ({1})
ClevoTune — first-time setup	ClevoTune — primeira configuração	ClevoTune — première configuration	ClevoTune — configuración inicial	ClevoTune — Ersteinrichtung	ClevoTune — prima configurazione
Not running as administrator: PawnIO cannot be installed.	Sem administrador: não é possível instalar o PawnIO.	Pas administrateur : impossible d'installer PawnIO.	Sin administrador: no se puede instalar PawnIO.	Keine Administratorrechte: PawnIO kann nicht installiert werden.	Senza amministratore: impossibile installare PawnIO.
Downloading and installing the PawnIO driver (signed)…	A descarregar e instalar o driver PawnIO (assinado)…	Téléchargement et installation du pilote PawnIO (signé)…	Descargando e instalando el driver de PawnIO (firmado)…	PawnIO-Treiber (signiert) wird heruntergeladen und installiert…	Download e installazione del driver PawnIO (firmato)…
PawnIO installation failed: {0}	Instalação do PawnIO falhou: {0}	Échec de l'installation de PawnIO : {0}	Falló la instalación de PawnIO: {0}	PawnIO-Installation fehlgeschlagen: {0}	Installazione di PawnIO non riuscita: {0}
PawnIO is installed but the driver is not active yet — a restart may be needed.	PawnIO instalado mas o driver ainda não está ativo — pode ser preciso reiniciar.	PawnIO est installé mais le pilote n'est pas encore actif — un redémarrage peut être nécessaire.	PawnIO está instalado pero el driver aún no está activo — puede ser necesario reiniciar.	PawnIO ist installiert, der Treiber ist aber noch nicht aktiv — evtl. ist ein Neustart nötig.	PawnIO è installato ma il driver non è ancora attivo — potrebbe servire un riavvio.
Downloading the PawnIO modules (fan EC and CPU MSR)…	A descarregar os módulos PawnIO (EC das ventoinhas e MSR do CPU)…	Téléchargement des modules PawnIO (EC des ventilateurs et MSR du CPU)…	Descargando los módulos de PawnIO (EC de ventiladores y MSR de la CPU)…	PawnIO-Module werden heruntergeladen (Lüfter-EC und CPU-MSR)…	Download dei moduli PawnIO (EC delle ventole e MSR della CPU)…
Module download failed: {0}	Descarga dos módulos falhou: {0}	Échec du téléchargement des modules : {0}	Falló la descarga de los módulos: {0}	Modul-Download fehlgeschlagen: {0}	Download dei moduli non riuscito: {0}
PawnIO ready	PawnIO pronto	PawnIO prêt	PawnIO listo	PawnIO bereit	PawnIO pronto
PawnIO partial	PawnIO parcial	PawnIO partiel	PawnIO parcial	PawnIO teilweise	PawnIO parziale
PawnIO missing	PawnIO em falta	PawnIO manquant	Falta PawnIO	PawnIO fehlt	PawnIO mancante
NVAPI ready	NVAPI pronto	NVAPI prêt	NVAPI listo	NVAPI bereit	NVAPI pronto
NVAPI unavailable	NVAPI indisponível	NVAPI indisponible	NVAPI no disponible	NVAPI nicht verfügbar	NVAPI non disponibile
No admin	Sem admin	Pas admin	Sin admin	Kein Admin	Senza admin
PawnIO driver: {0}	Driver PawnIO: {0}	Pilote PawnIO : {0}	Driver de PawnIO: {0}	PawnIO-Treiber: {0}	Driver PawnIO: {0}
installed	instalado	installé	instalado	installiert	installato
NOT installed	NÃO instalado	NON installé	NO instalado	NICHT installiert	NON installato
EC / fans (LpcACPIEC.bin): {0}	EC / ventoinhas (LpcACPIEC.bin): {0}	EC / ventilateurs (LpcACPIEC.bin) : {0}	EC / ventiladores (LpcACPIEC.bin): {0}	EC / Lüfter (LpcACPIEC.bin): {0}	EC / ventole (LpcACPIEC.bin): {0}
CPU temp/power (IntelMSR.bin): {0}	CPU temp/consumo (IntelMSR.bin): {0}	Temp./consommation CPU (IntelMSR.bin) : {0}	Temp./consumo CPU (IntelMSR.bin): {0}	CPU-Temp./Leistung (IntelMSR.bin): {0}	Temp./consumo CPU (IntelMSR.bin): {0}
PawnIO driver not installed	driver PawnIO não instalado	pilote PawnIO non installé	driver de PawnIO no instalado	PawnIO-Treiber nicht installiert	driver PawnIO non installato
LpcACPIEC.bin not found	LpcACPIEC.bin não encontrado	LpcACPIEC.bin introuvable	LpcACPIEC.bin no encontrado	LpcACPIEC.bin nicht gefunden	LpcACPIEC.bin non trovato
IntelMSR.bin not found	IntelMSR.bin não encontrado	IntelMSR.bin introuvable	IntelMSR.bin no encontrado	IntelMSR.bin nicht gefunden	IntelMSR.bin non trovato
Modules: {0}	Módulos: {0}	Modules : {0}	Módulos: {0}	Module: {0}	Moduli: {0}
Settings: {0}	Configuração: {0}	Configuration : {0}	Configuración: {0}	Einstellungen: {0}	Configurazione: {0}
Auto-apply: {0}	Auto-aplicar: {0}	Application auto : {0}	Autoaplicar: {0}	Auto-Anwenden: {0}	Applicazione auto: {0}
Auto-apply: off	Auto-aplicar: desligado	Application auto : désactivée	Autoaplicar: desactivado	Auto-Anwenden: aus	Applicazione auto: disattivata
Language changed: {0}	Idioma alterado: {0}	Langue modifiée : {0}	Idioma cambiado: {0}	Sprache geändert: {0}	Lingua cambiata: {0}
{0} W vs stock	{0} W vs stock	{0} W vs origine	{0} W vs. de serie	{0} W vs. Standard	{0} W vs stock
{0} MHz vs stock	{0} MHz vs stock	{0} MHz vs origine	{0} MHz vs. de serie	{0} MHz vs. Standard	{0} MHz vs stock
locked by vBIOS/driver	fixo pelo vBIOS/driver	verrouillé par le vBIOS/pilote	bloqueado por el vBIOS/driver	durch vBIOS/Treiber gesperrt	bloccato da vBIOS/driver
on card: {0} W	no cartão: {0} W	sur la carte : {0} W	en la tarjeta: {0} W	auf der Karte: {0} W	sulla scheda: {0} W
on card: {0} W (not adjustable)	no cartão: {0} W (não ajustável)	sur la carte : {0} W (non réglable)	en la tarjeta: {0} W (no ajustable)	auf der Karte: {0} W (nicht einstellbar)	sulla scheda: {0} W (non regolabile)
NVML unavailable	NVML indisponível	NVML indisponible	NVML no disponible	NVML nicht verfügbar	NVML non disponibile
on card: {0} MHz	no cartão: {0} MHz	sur la carte : {0} MHz	en la tarjeta: {0} MHz	auf der Karte: {0} MHz	sulla scheda: {0} MHz
(locked)	(bloqueado)	(verrouillé)	(bloqueado)	(gesperrt)	(bloccato)
on card: {0}	no cartão: {0}	sur la carte : {0}	en la tarjeta: {0}	auf der Karte: {0}	sulla scheda: {0}
applied: {0} MHz	aplicado: {0} MHz	appliqué : {0} MHz	aplicado: {0} MHz	angewendet: {0} MHz	applicato: {0} MHz
Power {0} W: {1}	Potência {0} W: {1}	Puissance {0} W : {1}	Potencia {0} W: {1}	Leistung {0} W: {1}	Potenza {0} W: {1}
Core offset {0} MHz: {1}	Offset núcleo {0} MHz: {1}	Décalage cœur {0} MHz : {1}	Offset núcleo {0} MHz: {1}	Kern-Offset {0} MHz: {1}	Offset core {0} MHz: {1}
core {0}	núcleo {0}	cœur {0}	núcleo {0}	Kern {0}	core {0}
Core offset: locked by the driver on this GPU	Offset núcleo: bloqueado pelo driver nesta GPU	Décalage cœur : verrouillé par le pilote sur ce GPU	Offset núcleo: bloqueado por el driver en esta GPU	Kern-Offset: vom Treiber auf dieser GPU gesperrt	Offset core: bloccato dal driver su questa GPU
Memory offset {0} MHz: {1}	Offset memória {0} MHz: {1}	Décalage mémoire {0} MHz : {1}	Offset memoria {0} MHz: {1}	Speicher-Offset {0} MHz: {1}	Offset memoria {0} MHz: {1}
Memory offset: locked by the driver on this GPU	Offset memória: bloqueado pelo driver nesta GPU	Décalage mémoire : verrouillé par le pilote sur ce GPU	Offset memoria: bloqueado por el driver en esta GPU	Speicher-Offset: vom Treiber auf dieser GPU gesperrt	Offset memoria: bloccato dal driver su questa GPU
NVAPI unavailable: {0}	NVAPI indisponível: {0}	NVAPI indisponible : {0}	NVAPI no disponible: {0}	NVAPI nicht verfügbar: {0}	NVAPI non disponibile: {0}
Clock limit {0} MHz: {1}	Limite de clock {0} MHz: {1}	Limite de fréquence {0} MHz : {1}	Límite de reloj {0} MHz: {1}	Taktlimit {0} MHz: {1}	Limite di clock {0} MHz: {1}
limit {0}	limite {0}	limite {0}	límite {0}	Limit {0}	limite {0}
Remove clock limit: {0}	Remover limite de clock: {0}	Retrait de la limite de fréquence : {0}	Quitar límite de reloj: {0}	Taktlimit entfernen: {0}	Rimozione limite di clock: {0}
{0} — see log	{0} — ver registo	{0} — voir le journal	{0} — ver registro	{0} — siehe Protokoll	{0} — vedi registro
Applied to card	Aplicado no cartão	Appliqué à la carte	Aplicado a la tarjeta	Auf Karte angewendet	Applicato alla scheda
Applied with warnings	Aplicado com avisos	Appliqué avec avertissements	Aplicado con avisos	Mit Warnungen angewendet	Applicato con avvisi
Applied	Aplicado	Appliqué	Aplicado	Angewendet	Applicato
Stock:	Stock:	Origine :	De serie:	Standard:	Stock:
Error: {0}	Erro: {0}	Erreur : {0}	Error: {0}	Fehler: {0}	Errore: {0}
Values re-read from the card	Valores relidos do cartão	Valeurs relues depuis la carte	Valores releídos de la tarjeta	Werte von der Karte neu gelesen	Valori riletti dalla scheda
On open: profile '{0}'	Ao abrir: perfil '{0}'	À l'ouverture : profil « {0} »	Al abrir: perfil '{0}'	Beim Öffnen: Profil '{0}'	All'apertura: profilo '{0}'
Profile '{0}':	Perfil '{0}':	Profil « {0} » :	Perfil '{0}':	Profil '{0}':	Profilo '{0}':
stock power	potência stock	puissance d'origine	potencia de serie	Standardleistung	potenza stock
Load fills the sliders, Apply writes them	Carregar preenche os sliders, Aplicar escreve-os	Charger remplit les curseurs, Appliquer les écrit	Cargar rellena los controles, Aplicar los escribe	Laden füllt die Regler, Anwenden schreibt sie	Carica compila i cursori, Applica li scrive
Profile '{0}' loaded into the sliders — press Apply	Perfil '{0}' carregado nos sliders — carrega em Aplicar	Profil « {0} » chargé dans les curseurs — cliquez sur Appliquer	Perfil '{0}' cargado en los controles — pulsa Aplicar	Profil '{0}' in die Regler geladen — auf Anwenden klicken	Profilo '{0}' caricato nei cursori — premi Applica
Profile name:	Nome do perfil:	Nom du profil :	Nombre del perfil:	Profilname:	Nome del profilo:
Replace profile '{0}'?	Substituir o perfil '{0}'?	Remplacer le profil « {0} » ?	¿Sustituir el perfil '{0}'?	Profil '{0}' ersetzen?	Sostituire il profilo '{0}'?
Profile '{0}' saved	Perfil '{0}' guardado	Profil « {0} » enregistré	Perfil '{0}' guardado	Profil '{0}' gespeichert	Profilo '{0}' salvato
At least one profile must exist	Tem de existir pelo menos um perfil	Il faut au moins un profil	Debe existir al menos un perfil	Mindestens ein Profil muss vorhanden sein	Deve esistere almeno un profilo
Delete profile '{0}'?	Apagar o perfil '{0}'?	Supprimer le profil « {0} » ?	¿Eliminar el perfil '{0}'?	Profil '{0}' löschen?	Eliminare il profilo '{0}'?
ClevoTune: GPU profile + fan curves at logon	ClevoTune: perfil GPU + curvas de ventoinha no arranque	ClevoTune : profil GPU + courbes de ventilateur à l'ouverture de session	ClevoTune: perfil GPU + curvas de ventilador al iniciar sesión	ClevoTune: GPU-Profil + Lüfterkurven bei der Anmeldung	ClevoTune: profilo GPU + curve ventole all'accesso
Start with Windows enabled (profile '{0}')	Arranque automático ativado (perfil '{0}')	Démarrage avec Windows activé (profil « {0} »)	Inicio con Windows activado (perfil '{0}')	Start mit Windows aktiviert (Profil '{0}')	Avvio con Windows attivato (profilo '{0}')
Start with Windows disabled	Arranque automático desativado	Démarrage avec Windows désactivé	Inicio con Windows desactivado	Start mit Windows deaktiviert	Avvio con Windows disattivato
Scheduled task failed: {0}	Falha na tarefa agendada: {0}	Échec de la tâche planifiée : {0}	Falló la tarea programada: {0}	Geplante Aufgabe fehlgeschlagen: {0}	Attività pianificata non riuscita: {0}
Could not create the scheduled task — see log	Não foi possível criar a tarefa agendada — ver registo	Impossible de créer la tâche planifiée — voir le journal	No se pudo crear la tarea programada — ver registro	Geplante Aufgabe konnte nicht erstellt werden — siehe Protokoll	Impossibile creare l'attività pianificata — vedi registro
Auto (EC)	Auto (EC)	Auto (EC)	Auto (EC)	Auto (EC)	Auto (EC)
Fan control unavailable: {0}. See the Settings tab.	Controlo de ventoinhas indisponível: {0}. Vê a aba Definições.	Contrôle des ventilateurs indisponible : {0}. Voir l'onglet Paramètres.	Control de ventiladores no disponible: {0}. Mira la pestaña Ajustes.	Lüftersteuerung nicht verfügbar: {0}. Siehe Reiter Einstellungen.	Controllo ventole non disponibile: {0}. Vedi la scheda Impostazioni.
Closing the app returns the fans to the EC's automatic control.	Fechar a app devolve as ventoinhas ao controlo automático do EC.	Fermer l'application rend les ventilateurs au contrôle automatique de l'EC.	Cerrar la app devuelve los ventiladores al control automático del EC.	Beim Beenden übernimmt der EC wieder die automatische Lüftersteuerung.	Chiudendo l'app le ventole tornano al controllo automatico dell'EC.
Fan {0} · {1}	Ventoinha {0} · {1}	Ventilateur {0} · {1}	Ventilador {0} · {1}	Lüfter {0} · {1}	Ventola {0} · {1}
Fan {0} ({1}): mode {2}	Ventoinha {0} ({1}): modo {2}	Ventilateur {0} ({1}) : mode {2}	Ventilador {0} ({1}): modo {2}	Lüfter {0} ({1}): Modus {2}	Ventola {0} ({1}): modalità {2}
Fan {0} ({1}): input {2}	Ventoinha {0} ({1}): entrada {2}	Ventilateur {0} ({1}) : entrée {2}	Ventilador {0} ({1}): entrada {2}	Lüfter {0} ({1}): Eingang {2}	Ventola {0} ({1}): ingresso {2}
EC automatic · {0} RPM · {1} %	EC automático · {0} RPM · {1} %	EC automatique · {0} tr/min · {1} %	EC automático · {0} RPM · {1} %	EC automatisch · {0} U/min · {1} %	EC automatico · {0} RPM · {1} %
max	máx	max	máx	max	max
max load	carga máx	charge max	carga máx	max. Last	carico max
SAFETY	SEGURANÇA	SÉCURITÉ	SEGURIDAD	SICHERHEIT	SICUREZZA
All fans returned to the EC (auto)	Todas as ventoinhas devolvidas ao EC (auto)	Tous les ventilateurs rendus à l'EC (auto)	Todos los ventiladores devueltos al EC (auto)	Alle Lüfter an den EC zurückgegeben (auto)	Tutte le ventole restituite all'EC (auto)
Fans in EC automatic mode	Ventoinhas em modo automático do EC	Ventilateurs en mode automatique de l'EC	Ventiladores en modo automático del EC	Lüfter im automatischen EC-Modus	Ventole in modalità automatica dell'EC
invalid line: '{0}'	linha inválida: '{0}'	ligne invalide : « {0} »	línea no válida: '{0}'	ungültige Zeile: '{0}'	riga non valida: '{0}'
expected 20 values (10 CPU + 10 GPU), found {0}	esperava 20 valores (10 CPU + 10 GPU), encontrei {0}	20 valeurs attendues (10 CPU + 10 GPU), {0} trouvées	se esperaban 20 valores (10 CPU + 10 GPU), se encontraron {0}	20 Werte erwartet (10 CPU + 10 GPU), {0} gefunden	attesi 20 valori (10 CPU + 10 GPU), trovati {0}
Curves imported from {0}: CPU {1} | GPU {2}	Curvas importadas de {0}: CPU {1} | GPU {2}	Courbes importées depuis {0} : CPU {1} | GPU {2}	Curvas importadas de {0}: CPU {1} | GPU {2}	Kurven importiert aus {0}: CPU {1} | GPU {2}	Curve importate da {0}: CPU {1} | GPU {2}
Curve imported from {0} to fan {1}: {2}	Curva importada de {0} para a ventoinha {1}: {2}	Courbe importée depuis {0} pour le ventilateur {1} : {2}	Curva importada de {0} al ventilador {1}: {2}	Kurve aus {0} für Lüfter {1} importiert: {2}	Curva importata da {0} per la ventola {1}: {2}
Curves imported and active (Curve mode)	Curvas importadas e ativas (modo Curva)	Courbes importées et actives (mode Courbe)	Curvas importadas y activas (modo Curva)	Kurven importiert und aktiv (Kurvenmodus)	Curve importate e attive (modalità Curva)
Curves exported to {0}	Curvas exportadas para {0}	Courbes exportées vers {0}	Curvas exportadas a {0}	Kurven exportiert nach {0}	Curve esportate in {0}
(points outside the 40–85 °C grid converted by interpolation)	(pontos fora da grelha 40–85 °C convertidos por interpolação)	(points hors de la grille 40–85 °C convertis par interpolation)	(puntos fuera de la rejilla 40–85 °C convertidos por interpolación)	(Punkte außerhalb des 40–85-°C-Rasters per Interpolation umgerechnet)	(punti fuori dalla griglia 40–85 °C convertiti per interpolazione)
Fixed grid: 10 points at 40, 45 … 85 °C, as in ClevoFanControl. Edit only the % in the table or drag the points vertically. Below 40 °C the 1st value is used, above 85 °C the last.	Grelha fixa: 10 pontos a 40, 45 … 85 °C, como no ClevoFanControl. Edita só a % na tabela ou arrasta os pontos na vertical. Abaixo de 40 °C usa o 1.º valor, acima de 85 °C o último.	Grille fixe : 10 points à 40, 45 … 85 °C, comme dans ClevoFanControl. Modifiez seulement le % dans le tableau ou déplacez les points verticalement. Sous 40 °C, la 1re valeur est utilisée, au-dessus de 85 °C la dernière.	Rejilla fija: 10 puntos a 40, 45 … 85 °C, como en ClevoFanControl. Edita solo el % en la tabla o arrastra los puntos en vertical. Por debajo de 40 °C se usa el 1.er valor, por encima de 85 °C el último.	Festes Raster: 10 Punkte bei 40, 45 … 85 °C wie in ClevoFanControl. Nur den %-Wert in der Tabelle ändern oder Punkte vertikal ziehen. Unter 40 °C gilt der 1. Wert, über 85 °C der letzte.	Griglia fissa: 10 punti a 40, 45 … 85 °C, come in ClevoFanControl. Modifica solo la % nella tabella o trascina i punti in verticale. Sotto i 40 °C si usa il 1° valore, sopra gli 85 °C l'ultimo.
Drag the points on the chart or type the values in the table. Double-click the chart to add a point; right-click a point to remove it.	Arrasta os pontos no gráfico ou escreve os valores na tabela. Duplo clique no gráfico adiciona um ponto; clique direito num ponto remove-o.	Faites glisser les points sur le graphique ou saisissez les valeurs dans le tableau. Double-clic sur le graphique pour ajouter un point ; clic droit sur un point pour le retirer.	Arrastra los puntos en el gráfico o escribe los valores en la tabla. Doble clic en el gráfico añade un punto; clic derecho en un punto lo quita.	Punkte im Diagramm ziehen oder Werte in die Tabelle eingeben. Doppelklick ins Diagramm fügt einen Punkt hinzu; Rechtsklick auf einen Punkt entfernt ihn.	Trascina i punti sul grafico o scrivi i valori nella tabella. Doppio clic sul grafico aggiunge un punto; clic destro su un punto lo rimuove.
ClevoFanControl curves (*.cfg)|*.cfg|All files (*.*)|*.*	Curvas ClevoFanControl (*.cfg)|*.cfg|Todos os ficheiros (*.*)|*.*	Courbes ClevoFanControl (*.cfg)|*.cfg|Tous les fichiers (*.*)|*.*	Curvas de ClevoFanControl (*.cfg)|*.cfg|Todos los archivos (*.*)|*.*	ClevoFanControl-Kurven (*.cfg)|*.cfg|Alle Dateien (*.*)|*.*	Curve ClevoFanControl (*.cfg)|*.cfg|Tutti i file (*.*)|*.*
Import failed: {0}	Importação falhou: {0}	Échec de l'import : {0}	Falló la importación: {0}	Import fehlgeschlagen: {0}	Importazione non riuscita: {0}
Invalid curve file — see log	Ficheiro de curvas inválido — ver registo	Fichier de courbes invalide — voir le journal	Archivo de curvas no válido — ver registro	Ungültige Kurvendatei — siehe Protokoll	File delle curve non valido — vedi registro
Exported: {0}	Exportado: {0}	Exporté : {0}	Exportado: {0}	Exportiert: {0}	Esportato: {0}
Export failed: {0}	Exportação falhou: {0}	Échec de l'export : {0}	Falló la exportación: {0}	Export fehlgeschlagen: {0}	Esportazione non riuscita: {0}
Export failed — see log	Exportação falhou — ver registo	Échec de l'export — voir le journal	Falló la exportación — ver registro	Export fehlgeschlagen — siehe Protokoll	Esportazione non riuscita — vedi registro
Curves saved (settings + {0})	Curvas guardadas (configuração + {0})	Courbes enregistrées (configuration + {0})	Curvas guardadas (configuración + {0})	Kurven gespeichert (Einstellungen + {0})	Curve salvate (configurazione + {0})
Save failed: {0}	Guardar falhou: {0}	Échec de l'enregistrement : {0}	Falló al guardar: {0}	Speichern fehlgeschlagen: {0}	Salvataggio non riuscito: {0}
Save failed — see log	Guardar falhou — ver registo	Échec de l'enregistrement — voir le journal	Falló al guardar — ver registro	Speichern fehlgeschlagen — siehe Protokoll	Salvataggio non riuscito — vedi registro
Sensors reinitialised	Sensores reinicializados	Capteurs réinitialisés	Sensores reiniciados	Sensoren neu initialisiert	Sensori reinizializzati
Reinitialisation error: {0}	Erro ao reinicializar: {0}	Erreur de réinitialisation : {0}	Error al reiniciar: {0}	Fehler bei der Neuinitialisierung: {0}	Errore di reinizializzazione: {0}
Reinstalling PawnIO driver and modules…	A reinstalar driver PawnIO e módulos…	Réinstallation du pilote PawnIO et des modules…	Reinstalando driver de PawnIO y módulos…	PawnIO-Treiber und Module werden neu installiert…	Reinstallazione di driver PawnIO e moduli…
Installed — restart Windows to activate the driver	Instalado — reinicia o Windows para ativar o driver	Installé — redémarrez Windows pour activer le pilote	Instalado — reinicia Windows para activar el driver	Installiert — Windows neu starten, um den Treiber zu aktivieren	Installato — riavvia Windows per attivare il driver
Reinstall failed: {0}	Falha na reinstalação: {0}	Échec de la réinstallation : {0}	Falló la reinstalación: {0}	Neuinstallation fehlgeschlagen: {0}	Reinstallazione non riuscita: {0}
Reinstall failed — see log	Falha na reinstalação — ver registo	Échec de la réinstallation — voir le journal	Falló la reinstalación — ver registro	Neuinstallation fehlgeschlagen — siehe Protokoll	Reinstallazione non riuscita — vedi registro
Open ClevoTune	Abrir ClevoTune	Ouvrir ClevoTune	Abrir ClevoTune	ClevoTune öffnen	Apri ClevoTune
Apply profile: {0}	Aplicar perfil: {0}	Appliquer le profil : {0}	Aplicar perfil: {0}	Profil anwenden: {0}	Applica profilo: {0}
Fans → automatic (EC)	Ventoinhas → automático (EC)	Ventilateurs → automatique (EC)	Ventiladores → automático (EC)	Lüfter → automatisch (EC)	Ventole → automatico (EC)
Exit (returns fans to the EC)	Sair (devolve ventoinhas ao EC)	Quitter (rend les ventilateurs à l'EC)	Salir (devuelve los ventiladores al EC)	Beenden (Lüfter zurück an den EC)	Esci (restituisce le ventole all'EC)
Still running in the tray controlling the fans. Right-click → Exit to close.	Continua no tabuleiro a controlar as ventoinhas. Clique direito → Sair para fechar.	Toujours actif dans la zone de notification pour piloter les ventilateurs. Clic droit → Quitter pour fermer.	Sigue en la bandeja controlando los ventiladores. Clic derecho → Salir para cerrar.	Läuft im Infobereich weiter und steuert die Lüfter. Rechtsklick → Beenden zum Schließen.	Continua nell'area di notifica a controllare le ventole. Clic destro → Esci per chiudere.
Fans returned to the EC	Ventoinhas devolvidas ao EC	Ventilateurs rendus à l'EC	Ventiladores devueltos al EC	Lüfter an den EC zurückgegeben	Ventole restituite all'EC
Unexpected error: {0}	Erro inesperado: {0}	Erreur inattendue : {0}	Error inesperado: {0}	Unerwarteter Fehler: {0}	Errore imprevisto: {0}
userfancurve.cfg ignored: {0}	userfancurve.cfg ignorado: {0}	userfancurve.cfg ignoré : {0}	userfancurve.cfg ignorado: {0}	userfancurve.cfg ignoriert: {0}	userfancurve.cfg ignorato: {0}
Warning: no administrator rights — PawnIO and GPU changes will fail.	Aviso: sem privilégios de administrador — PawnIO e alterações à GPU vão falhar.	Attention : pas de droits administrateur — PawnIO et les réglages GPU échoueront.	Aviso: sin privilegios de administrador — PawnIO y los cambios en la GPU fallarán.	Warnung: keine Administratorrechte — PawnIO und GPU-Änderungen werden fehlschlagen.	Avviso: nessun privilegio di amministratore — PawnIO e le modifiche alla GPU non funzioneranno.
PawnIO installed — restart Windows to enable the fans and CPU sensors	PawnIO instalado — reinicia o Windows para ativar as ventoinhas e sensores do CPU	PawnIO installé — redémarrez Windows pour activer les ventilateurs et capteurs CPU	PawnIO instalado — reinicia Windows para activar los ventiladores y sensores de la CPU	PawnIO installiert — Windows neu starten, um Lüfter und CPU-Sensoren zu aktivieren	PawnIO installato — riavvia Windows per attivare le ventole e i sensori della CPU
Fans: {0}	Ventoinhas: {0}	Ventilateurs : {0}	Ventiladores: {0}	Lüfter: {0}	Ventole: {0}
Fans detected: {0}	Ventoinhas detetadas: {0}	Ventilateurs détectés : {0}	Ventiladores detectados: {0}	Erkannte Lüfter: {0}	Ventole rilevate: {0}
Warning: Clevo Control Center is running and may override the curves.	Aviso: o Control Center da Clevo está a correr e pode sobrepor-se às curvas.	Attention : le Control Center de Clevo est actif et peut écraser les courbes.	Aviso: el Control Center de Clevo se está ejecutando y puede anular las curvas.	Warnung: Das Clevo Control Center läuft und kann die Kurven überschreiben.	Avviso: il Control Center di Clevo è in esecuzione e può sovrascrivere le curve.
Ready	Pronto	Prêt	Listo	Bereit	Pronto
Safety: {0} °C ≥ {1} °C → fans at 100%	Segurança: {0} °C ≥ {1} °C → ventoinhas a 100%	Sécurité : {0} °C ≥ {1} °C → ventilateurs à 100 %	Seguridad: {0} °C ≥ {1} °C → ventiladores al 100%	Sicherheit: {0} °C ≥ {1} °C → Lüfter auf 100 %	Sicurezza: {0} °C ≥ {1} °C → ventole al 100%
Fan {0}: {1}	Ventoinha {0}: {1}	Ventilateur {0} : {1}	Ventilador {0}: {1}	Lüfter {0}: {1}	Ventola {0}: {1}
error ({0})	erro ({0})	erreur ({0})	error ({0})	Fehler ({0})	errore ({0})
invalid argument / out of range	argumento inválido / fora do intervalo	argument invalide / hors limites	argumento no válido / fuera de rango	ungültiges Argument / außerhalb des Bereichs	argomento non valido / fuori intervallo
NVIDIA GPU not found	GPU NVIDIA não encontrada	GPU NVIDIA introuvable	GPU NVIDIA no encontrada	NVIDIA-GPU nicht gefunden	GPU NVIDIA non trovata
incompatible structure version	versão de estrutura incompatível	version de structure incompatible	versión de estructura incompatible	inkompatible Strukturversion	versione della struttura incompatibile
not supported by this GPU/vBIOS	não suportado por esta GPU/vBIOS	non pris en charge par ce GPU/vBIOS	no compatible con esta GPU/vBIOS	von dieser GPU/diesem vBIOS nicht unterstützt	non supportato da questa GPU/vBIOS
no permission	sem permissões	permission refusée	sin permisos	keine Berechtigung	nessun permesso
Open language folder	Abrir pasta de idiomas	Ouvrir le dossier des langues	Abrir carpeta de idiomas	Sprachordner öffnen	Apri cartella lingue
Start with Windows (at sign-in)	Iniciar com o Windows (ao iniciar sessão)	Démarrer avec Windows (à l'ouverture de session)	Iniciar con Windows (al iniciar sesión)	Mit Windows starten (bei der Anmeldung)	Avvia con Windows (all'accesso)
Starts minimised in the tray when you sign in to Windows, without a UAC prompt, applies the last profile and controls the fans	Inicia minimizado no tabuleiro quando entras no Windows, sem pedido de UAC, aplica o último perfil e controla as ventoinhas	Démarre réduit dans la zone de notification à l'ouverture de session, sans invite UAC, applique le dernier profil et pilote les ventilateurs	Se inicia minimizado en la bandeja al iniciar sesión en Windows, sin aviso de UAC, aplica el último perfil y controla los ventiladores	Startet bei der Windows-Anmeldung minimiert im Infobereich, ohne UAC-Abfrage, wendet das letzte Profil an und steuert die Lüfter	Si avvia ridotto nell'area di notifica all'accesso a Windows, senza richiesta UAC, applica l'ultimo profilo e controlla le ventole
Start with Windows	Iniciar com o Windows	Démarrer avec Windows	Iniciar con Windows	Mit Windows starten	Avvia con Windows
Starts with Windows at sign-in	Inicia com o Windows ao iniciar sessão	Démarre avec Windows à l'ouverture de session	Se inicia con Windows al iniciar sesión	Startet mit Windows bei der Anmeldung	Si avvia con Windows all'accesso
CPU TEMP	CPU TEMP	TEMP. CPU	TEMP. CPU	CPU-TEMP.	TEMP. CPU
CPU FAN	CPU FAN	VENTIL. CPU	VENT. CPU	CPU-LÜFTER	VENTOLA CPU
CPU CLOCK	CPU CLOCK	FRÉQ. CPU	RELOJ CPU	CPU-TAKT	CLOCK CPU
CPU LOAD	CPU LOAD	CHARGE CPU	CARGA CPU	CPU-LAST	CARICO CPU
CPU POWER	CPU POWER	PUISS. CPU	POTENCIA CPU	CPU-LEISTUNG	POTENZA CPU
GPU TEMP	GPU TEMP	TEMP. GPU	TEMP. GPU	GPU-TEMP.	TEMP. GPU
GPU FAN	GPU FAN	VENTIL. GPU	VENT. GPU	GPU-LÜFTER	VENTOLA GPU
GPU CLOCK	GPU CLOCK	FRÉQ. GPU	RELOJ GPU	GPU-TAKT	CLOCK GPU
GPU LOAD	GPU LOAD	CHARGE GPU	CARGA GPU	GPU-LAST	CARICO GPU
GPU POWER	GPU POWER	PUISS. GPU	POTENCIA GPU	GPU-LEISTUNG	POTENZA GPU
'@
# built-in languages (columns of the table above) and their file names in the Language folder
$BuiltinLangs = @(
    @{ Code = 'en-us'; Name = 'English'; Col = 0 },
    @{ Code = 'pt'; Name = 'Português'; Col = 1 },
    @{ Code = 'fr'; Name = 'Français'; Col = 2 },
    @{ Code = 'es'; Name = 'Español'; Col = 3 },
    @{ Code = 'de'; Name = 'Deutsch'; Col = 4 },
    @{ Code = 'it'; Name = 'Italiano'; Col = 5 }
)
$script:LangRows = New-Object System.Collections.ArrayList
$script:LangKeys = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($line in ($LangTable -split "`r?`n")) {
    if (-not $line) { continue }
    $cols = $line -split "`t"
    [void]$script:LangRows.Add($cols)
    [void]$script:LangKeys.Add($cols[0])
}
$script:LangMap = New-Object 'System.Collections.Generic.Dictionary[string,string]'
$script:Lang = 'pt'
$script:Langs = New-Object System.Collections.ArrayList   # @{ Code; Name; File; Map; Col }

function Get-LangDir {
    $d = Join-Path $SelfDir 'Language'
    try {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        $probe = Join-Path $d '.write-test'
        [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force
        return $d
    } catch {
        if (Test-Path -LiteralPath (Join-Path $d '*.lng')) { return $d }   # read-only but already populated
        $d = Join-Path (Join-Path $env:APPDATA 'ClevoTune') 'Language'
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        return $d
    }
}

function New-LangFileText($bl) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('; ClevoTune language file - edit the text after the first "=" on each line.')
    [void]$sb.AppendLine('; The text before "=" is the original English text and must not be changed.')
    [void]$sb.AppendLine('; Missing or empty lines fall back to the built-in text. Lines starting with ; are comments.')
    [void]$sb.AppendLine('[info]')
    [void]$sb.AppendLine('name=' + $bl.Name)
    [void]$sb.AppendLine('code=' + $bl.Code)
    [void]$sb.AppendLine('base=en')
    [void]$sb.AppendLine('version=' + $AppVersion)
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('[strings]')
    foreach ($r in $script:LangRows) { [void]$sb.AppendLine($r[0] + '=' + $r[$bl.Col]) }
    return $sb.ToString()
}

function Read-LangFile([string]$path) {
    $info = @{}; $map = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]'
    $sec = ''
    foreach ($line in [IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8)) {
        if (-not $line -or $line.StartsWith(';')) { continue }
        if ($line.StartsWith('[') -and $line.TrimEnd().EndsWith(']')) { $sec = $line.Trim().Trim('[', ']').ToLowerInvariant(); continue }
        $i = $line.IndexOf('=')
        if ($i -le 0) { continue }
        $k = $line.Substring(0, $i); $v = $line.Substring($i + 1)
        if ($sec -eq 'info') { $info[$k.Trim().ToLowerInvariant()] = $v.Trim() }
        else { [void]$seen.Add($k); if ($v.Length -gt 0) { $map[$k] = $v } }
    }
    return @{ Info = $info; Map = $map; Seen = $seen }
}

$script:LangNotes = New-Object System.Collections.ArrayList
# files from versions before 1.4.0 used the Portuguese text as key: convert them to English keys
function Convert-OldLangFile([string]$path, $d) {
    $pt2en = @{}
    foreach ($r in $script:LangRows) { if ($r.Count -gt 1 -and $r[1]) { $pt2en[$r[1]] = $r[0] } }
    try { Copy-Item -LiteralPath $path -Destination ($path + '.old') -Force } catch { }
    $code = [IO.Path]::GetFileNameWithoutExtension($path).ToLowerInvariant()
    $bl = $BuiltinLangs | Where-Object { $_.Code -eq $code } | Select-Object -First 1
    if ($bl) {
        # built-in language: start from the current built-in text, keep the user's own edits
        $text = New-LangFileText $bl
        $lines = New-Object System.Collections.ArrayList
        foreach ($l in ($text -split "`r?`n")) { [void]$lines.Add($l) }
        foreach ($k in $d.Map.Keys) {
            if (-not $pt2en.ContainsKey($k)) { continue }
            $en = $pt2en[$k]
            for ($i = 0; $i -lt $lines.Count; $i++) {
                if ($lines[$i].StartsWith($en + '=')) { $lines[$i] = $en + '=' + $d.Map[$k]; break }
            }
        }
        [IO.File]::WriteAllText($path, (($lines -join "`r`n").TrimEnd() + "`r`n"), (New-Object Text.UTF8Encoding($true)))
    } else {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine('; ClevoTune language file - edit the text after the first "=" on each line.')
        [void]$sb.AppendLine('; The text before "=" is the original English text and must not be changed.')
        [void]$sb.AppendLine('[info]')
        foreach ($k in $d.Info.Keys) { if ($k -ne 'base') { [void]$sb.AppendLine($k + '=' + $d.Info[$k]) } }
        [void]$sb.AppendLine('base=en')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('[strings]')
        foreach ($k in $d.Map.Keys) { $en = $(if ($pt2en.ContainsKey($k)) { $pt2en[$k] } else { $k }); [void]$sb.AppendLine($en + '=' + $d.Map[$k]) }
        [IO.File]::WriteAllText($path, $sb.ToString(), (New-Object Text.UTF8Encoding($true)))
    }
    [void]$script:LangNotes.Add('Language file converted to English keys: ' + [IO.Path]::GetFileName($path) + ' (backup: .old)')
}

function Load-Languages {
    $script:Langs.Clear()
    $dir = $null
    try { $dir = Get-LangDir } catch { }
    if ($dir) {
        # write any missing built-in language file; never overwrite the user's edits
        foreach ($bl in $BuiltinLangs) {
            $f = Join-Path $dir ($bl.Code + '.lng')
            if (-not (Test-Path -LiteralPath $f)) {
                try { [IO.File]::WriteAllText($f, (New-LangFileText $bl), (New-Object Text.UTF8Encoding($true))) } catch { }
            }
        }
        foreach ($file in (Get-ChildItem -LiteralPath $dir -Filter '*.lng' -ErrorAction SilentlyContinue | Sort-Object Name)) {
            try {
                $d = Read-LangFile $file.FullName
                if ($d.Info['base'] -ne 'en') { Convert-OldLangFile $file.FullName $d; $d = Read-LangFile $file.FullName }
                $code = $file.BaseName.ToLowerInvariant()
                $bl = $BuiltinLangs | Where-Object { $_.Code -eq $code } | Select-Object -First 1
                if ($bl) {
                    # texts added in newer versions: append them so the file stays complete for translators
                    $add = New-Object System.Text.StringBuilder
                    foreach ($r in $script:LangRows) { if (-not $d.Seen.Contains($r[0])) { [void]$add.AppendLine($r[0] + '=' + $r[$bl.Col]) } }
                    if ($add.Length -gt 0) { try { [IO.File]::AppendAllText($file.FullName, $add.ToString(), (New-Object Text.UTF8Encoding($false))) } catch { } }
                }
                $name = $d.Info['name']; if (-not $name) { if ($bl) { $name = $bl.Name } else { $name = $code } }
                $col = -1; if ($bl) { $col = $bl.Col }
                [void]$script:Langs.Add(@{ Code = $code; Name = $name; File = $file.FullName; Map = $d.Map; Col = $col })
            } catch { }
        }
    }
    # built-ins are always available, even without the folder
    foreach ($bl in $BuiltinLangs) {
        if (-not ($script:Langs | Where-Object { $_.Code -eq $bl.Code })) {
            [void]$script:Langs.Add(@{ Code = $bl.Code; Name = $bl.Name; File = $null; Map = $null; Col = $bl.Col })
        }
    }
    $order = @{}; for ($i = 0; $i -lt $BuiltinLangs.Count; $i++) { $order[$BuiltinLangs[$i].Code] = $i }
    $sorted = @($script:Langs | Sort-Object { if ($order.ContainsKey($_.Code)) { $order[$_.Code] } else { 100 } }, { $_.Name })
    $script:Langs.Clear(); foreach ($l in $sorted) { [void]$script:Langs.Add($l) }
    $script:LangDir = $dir
}

function Find-Lang([string]$code) {
    if (-not $code) { return $null }
    $c = $code.ToLowerInvariant()
    foreach ($l in $script:Langs) { if ($l.Code -eq $c) { return $l } }
    $two = $c.Split('-')[0]
    foreach ($l in $script:Langs) { if ($l.Code -eq $two -or $l.Code.Split('-')[0] -eq $two) { return $l } }
    return $null
}

function Resolve-Lang([string]$pref) {
    if ($pref -and $pref -ne 'auto') { $l = Find-Lang $pref; if ($l) { return $l.Code } }
    $sys = 'en-us'
    try { $sys = [Globalization.CultureInfo]::CurrentUICulture.Name } catch { }
    $l = Find-Lang $sys; if ($l) { return $l.Code }
    $l = Find-Lang 'en-us'; if ($l) { return $l.Code }
    return 'en-us'
}

function Set-Lang([string]$code) {
    $l = Find-Lang $code
    if (-not $l) { $l = Find-Lang 'en-us' }
    $script:Lang = $l.Code
    $m = New-Object 'System.Collections.Generic.Dictionary[string,string]'
    if ($l.Col -gt 0) { foreach ($r in $script:LangRows) { if ($r.Count -gt $l.Col -and $r[$l.Col]) { $m[$r[0]] = $r[$l.Col] } } }
    if ($l.Map) { foreach ($k in $l.Map.Keys) { $m[$k] = $l.Map[$k] } }
    $script:LangMap = $m
    if ('ClevoTune.L' -as [type]) { [ClevoTune.L]::Load($m) }
}
function T([string]$k) { if ($null -ne $k -and $script:LangMap.ContainsKey($k)) { return $script:LangMap[$k] }; return $k }
Load-Languages
Set-Lang (Resolve-Lang 'auto')

trap {
    try { if ($script:Hw) { $script:Hw.ReleaseAll() } } catch { }
    try { [System.Windows.MessageBox]::Show("$(T 'Startup error:')`n`n$($_.Exception.Message)`n`n$($_.InvocationInfo.PositionMessage)", 'ClevoTune', 'OK', 'Error') | Out-Null } catch { }
    break
}

# ---------------------------------------------------------------- single instance
$createdNew = $false
$script:SingleMutex = New-Object System.Threading.Mutex($true, 'Local\ClevoTune.Single', [ref]$createdNew)
$script:ShowEvent   = New-Object System.Threading.EventWaitHandle($false, [System.Threading.EventResetMode]::AutoReset, 'Local\ClevoTune.Show')
if (-not $createdNew) { [void]$script:ShowEvent.Set(); return }

# ---------------------------------------------------------------- paths
$DataDir  = Join-Path $env:APPDATA 'ClevoTune'
$CacheDir = Join-Path $env:LOCALAPPDATA 'ClevoTune'
$CfgPath  = Join-Path $DataDir 'config.json'
$LogPath  = Join-Path $DataDir 'clevotune.log'
foreach ($d in $DataDir, $CacheDir) { if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null } }
$ModDir = Join-Path $SelfDir 'modules'

function Find-Module([string]$name) {
    foreach ($p in (Join-Path $ModDir $name), (Join-Path $SelfDir $name), (Join-Path (Join-Path $DataDir 'modules') $name)) {
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return $null
}

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ---------------------------------------------------------------- C# core
$CoreSource = @'
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;

namespace ClevoTune
{
    // ---------------------------------------------------------------- i18n
    public static class L
    {
        static Dictionary<string, string> map = new Dictionary<string, string>();
        public static void Load(IDictionary<string, string> m) { map = new Dictionary<string, string>(m); }
        public static string T(string k)
        {
            string v;
            return (k != null && map.TryGetValue(k, out v)) ? v : k;
        }
    }

    // ------------------------------------------------------------------ PawnIO
    public class PawnIo : IDisposable
    {
        const uint IOCTL_LOAD = 0xA1B22084;
        const uint IOCTL_EXEC = 0xA1B22104;

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "CreateFileW")]
        static extern SafeFileHandle CreateFile(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);

        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool DeviceIoControl(SafeFileHandle h, uint code, byte[] inBuf, int inSize, byte[] outBuf, int outSize, out int returned, IntPtr ov);

        SafeFileHandle handle;

        static SafeFileHandle OpenDevice()
        {
            return CreateFile(@"\\?\GLOBALROOT\Device\PawnIO", 0xC0000000u, 3u, IntPtr.Zero, 3u, 0x80u, IntPtr.Zero);
        }

        public static bool DriverPresent()
        {
            SafeFileHandle h = OpenDevice();
            bool ok = !h.IsInvalid;
            h.Dispose();
            return ok;
        }

        public PawnIo(byte[] module)
        {
            handle = OpenDevice();
            if (handle.IsInvalid)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "PawnIO driver not available");
            int r;
            if (!DeviceIoControl(handle, IOCTL_LOAD, module, module.Length, null, 0, out r, IntPtr.Zero))
            {
                int e = Marshal.GetLastWin32Error();
                handle.Dispose();
                throw new Win32Exception(e, "PawnIO module load failed");
            }
        }

        public long[] Exec(string fn, long[] input, int outCount)
        {
            byte[] inb = new byte[32 + input.Length * 8];
            byte[] name = Encoding.ASCII.GetBytes(fn);
            Buffer.BlockCopy(name, 0, inb, 0, Math.Min(31, name.Length));
            Buffer.BlockCopy(input, 0, inb, 32, input.Length * 8);
            byte[] outb = outCount > 0 ? new byte[outCount * 8] : null;
            int ret;
            if (!DeviceIoControl(handle, IOCTL_EXEC, inb, inb.Length, outb, outb == null ? 0 : outb.Length, out ret, IntPtr.Zero))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            long[] res = new long[outCount];
            if (outb != null) Buffer.BlockCopy(outb, 0, res, 0, Math.Min(ret, outb.Length));
            return res;
        }

        public void Dispose()
        {
            if (handle != null) handle.Dispose();
        }
    }

    // ------------------------------------------------------- Clevo EC (0x62/0x66)
    public class ClevoEc : IDisposable
    {
        const int CMD = 0x66, DATA = 0x62;
        PawnIo io;
        Mutex mtx;

        public ClevoEc(byte[] module)
        {
            io = new PawnIo(module);
            try { mtx = new Mutex(false, @"Global\Access_EC"); } catch { mtx = null; }
        }

        int In(int port) { return (int)(io.Exec("ioctl_pio_read", new long[] { port }, 1)[0] & 0xFF); }
        void Out(int port, int v) { io.Exec("ioctl_pio_write", new long[] { port, v & 0xFF }, 0); }

        void WaitIbf()
        {
            Stopwatch sw = Stopwatch.StartNew();
            while ((In(CMD) & 2) != 0)
            {
                if (sw.ElapsedMilliseconds > 60) throw new TimeoutException("EC IBF timeout");
                Thread.Yield();
            }
        }

        void WaitObf()
        {
            Stopwatch sw = Stopwatch.StartNew();
            while ((In(CMD) & 1) == 0)
            {
                if (sw.ElapsedMilliseconds > 60) throw new TimeoutException("EC OBF timeout");
                Thread.Yield();
            }
        }

        void Drain()
        {
            for (int i = 0; i < 16 && (In(CMD) & 1) != 0; i++) In(DATA);
        }

        void Cmd(int c) { WaitIbf(); Out(CMD, c); }
        void Dat(int d) { WaitIbf(); Out(DATA, d); }
        int Rd() { WaitObf(); return In(DATA); }

        void Lock()
        {
            if (mtx == null) return;
            try
            {
                if (!mtx.WaitOne(250)) throw new TimeoutException("EC busy (Access_EC)");
            }
            catch (AbandonedMutexException) { }
        }

        void Unlock()
        {
            if (mtx == null) return;
            try { mtx.ReleaseMutex(); } catch { }
        }

        public int ReadReg(int addr)
        {
            Lock();
            try { Drain(); Cmd(0x80); Dat(addr); return Rd(); }
            finally { Unlock(); }
        }

        // returns { remote temp, local temp, duty raw 0-255 }
        public int[] FanInfo(int idx)
        {
            Lock();
            try
            {
                Drain(); Cmd(0x9E); Dat(idx);
                int a = Rd(); int b = Rd(); int c = Rd();
                return new int[] { a, b, c };
            }
            finally { Unlock(); }
        }

        public int FanRpm(int idx)
        {
            int baseReg = 0xD0 + (idx - 1) * 2;
            int hi = ReadReg(baseReg);
            int lo = ReadReg(baseReg + 1);
            int raw = (hi << 8) | lo;
            if (raw <= 0) return 0;
            int rpm = 2156220 / raw;
            return rpm > 12000 ? 0 : rpm;
        }

        public void SetDuty(int idx, int raw)
        {
            if (raw < 1) raw = 1;
            if (raw > 255) raw = 255;
            Lock();
            try { Drain(); Cmd(0x99); Dat(idx); Dat(raw); }
            finally { Unlock(); }
        }

        public void SetAuto(int idx)
        {
            Lock();
            try { Drain(); Cmd(0x99); Dat(0xFF); Dat(idx); }
            finally { Unlock(); }
        }

        public void Dispose()
        {
            if (io != null) io.Dispose();
            if (mtx != null) mtx.Dispose();
        }
    }

    // --------------------------------------------------------------- Intel MSR
    public class IntelMsr : IDisposable
    {
        PawnIo io;
        public IntelMsr(byte[] module) { io = new PawnIo(module); }
        public ulong Read(uint msr) { return unchecked((ulong)io.Exec("ioctl_read_msr", new long[] { msr }, 1)[0]); }
        public void Dispose() { if (io != null) io.Dispose(); }
    }

    // --------------------------------------------------------------------- PDH
    public class Pdh : IDisposable
    {
        [StructLayout(LayoutKind.Explicit)]
        struct FmtValue
        {
            [FieldOffset(0)] public uint CStatus;
            [FieldOffset(8)] public double Value;
        }

        [DllImport("pdh.dll", CharSet = CharSet.Unicode, EntryPoint = "PdhOpenQueryW")]
        static extern int PdhOpenQuery(string src, IntPtr user, out IntPtr q);
        [DllImport("pdh.dll", CharSet = CharSet.Unicode, EntryPoint = "PdhAddEnglishCounterW")]
        static extern int PdhAddEnglishCounter(IntPtr q, string path, IntPtr user, out IntPtr c);
        [DllImport("pdh.dll")]
        static extern int PdhCollectQueryData(IntPtr q);
        [DllImport("pdh.dll")]
        static extern int PdhGetFormattedCounterValue(IntPtr c, uint fmt, IntPtr type, out FmtValue v);
        [DllImport("pdh.dll")]
        static extern int PdhCloseQuery(IntPtr q);

        IntPtr q, cUtil, cPerf, cTime;
        bool ok;

        public Pdh()
        {
            if (PdhOpenQuery(null, IntPtr.Zero, out q) != 0) return;
            if (PdhAddEnglishCounter(q, @"\Processor Information(_Total)\% Processor Utility", IntPtr.Zero, out cUtil) != 0) cUtil = IntPtr.Zero;
            if (PdhAddEnglishCounter(q, @"\Processor Information(_Total)\% Processor Performance", IntPtr.Zero, out cPerf) != 0) cPerf = IntPtr.Zero;
            if (PdhAddEnglishCounter(q, @"\Processor(_Total)\% Processor Time", IntPtr.Zero, out cTime) != 0) cTime = IntPtr.Zero;
            PdhCollectQueryData(q);
            ok = true;
        }

        double Get(IntPtr c)
        {
            if (c == IntPtr.Zero) return double.NaN;
            FmtValue v;
            if (PdhGetFormattedCounterValue(c, 0x200 | 0x8000, IntPtr.Zero, out v) != 0) return double.NaN;
            return v.Value;
        }

        public void Collect(out double load, out double perfPct)
        {
            load = double.NaN; perfPct = double.NaN;
            if (!ok) return;
            PdhCollectQueryData(q);
            load = Get(cUtil);
            if (double.IsNaN(load)) load = Get(cTime);
            perfPct = Get(cPerf);
        }

        public void Dispose() { if (ok) PdhCloseQuery(q); ok = false; }
    }

    // -------------------------------------------------------------------- NVML
    public static class Nvml
    {
        [StructLayout(LayoutKind.Sequential)] public struct Util { public uint Gpu; public uint Memory; }
        [StructLayout(LayoutKind.Sequential)] public struct Mem { public ulong Total; public ulong Free; public ulong Used; }

        [DllImport("nvml.dll", EntryPoint = "nvmlInit_v2")] public static extern int Init();
        [DllImport("nvml.dll", EntryPoint = "nvmlShutdown")] public static extern int Shutdown();
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetHandleByIndex_v2")] public static extern int GetHandle(uint idx, out IntPtr dev);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetName", CharSet = CharSet.Ansi)] public static extern int GetName(IntPtr dev, StringBuilder name, uint len);
        [DllImport("nvml.dll", EntryPoint = "nvmlSystemGetDriverVersion", CharSet = CharSet.Ansi)] public static extern int GetDriver(StringBuilder ver, uint len);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetTemperature")] public static extern int GetTemp(IntPtr dev, int sensor, out uint t);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetClockInfo")] public static extern int GetClock(IntPtr dev, int type, out uint mhz);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetUtilizationRates")] public static extern int GetUtil(IntPtr dev, out Util u);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetPowerUsage")] public static extern int GetPower(IntPtr dev, out uint mw);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetMemoryInfo")] public static extern int GetMem(IntPtr dev, out Mem m);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetEnforcedPowerLimit")] public static extern int GetEnforcedLimit(IntPtr dev, out uint mw);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetPowerManagementDefaultLimit")] public static extern int GetDefaultLimit(IntPtr dev, out uint mw);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceGetPowerManagementLimitConstraints")] public static extern int GetLimitConstraints(IntPtr dev, out uint minMw, out uint maxMw);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceSetPowerManagementLimit")] public static extern int SetPowerLimit(IntPtr dev, uint mw);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceSetGpuLockedClocks")] public static extern int SetLockedClocks(IntPtr dev, uint minMhz, uint maxMhz);
        [DllImport("nvml.dll", EntryPoint = "nvmlDeviceResetGpuLockedClocks")] public static extern int ResetLockedClocks(IntPtr dev);
        [DllImport("nvml.dll", EntryPoint = "nvmlErrorString")] static extern IntPtr ErrorStringPtr(int code);

        public static string ErrorString(int code)
        {
            try { return Marshal.PtrToStringAnsi(ErrorStringPtr(code)); }
            catch { return "NVML error " + code; }
        }
    }

    // ------------------------------------------------------------------- NVAPI
    public class OffsetInfo
    {
        public int Status = -1;
        public int CoreMHz, CoreMin, CoreMax, MemMHz, MemMin, MemMax;
        public bool CoreEditable, MemEditable, CoreFound, MemFound;
        public int CoreBaseMHz, MemBaseMHz;
    }

    public class PowerPolicy
    {
        public int InfoStatus = -1, StatusStatus = -1;
        public bool Valid;
        public double MinPct = double.NaN, DefPct = double.NaN, MaxPct = double.NaN, CurPct = double.NaN;
    }

    public static class NvApi
    {
        [DllImport("nvapi64.dll", EntryPoint = "nvapi_QueryInterface", CallingConvention = CallingConvention.Cdecl)]
        static extern IntPtr QueryInterface(uint id);

        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int DInit();
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int DEnum([Out, MarshalAs(UnmanagedType.LPArray, SizeConst = 64)] IntPtr[] handles, out int count);
        [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int DPstates(IntPtr gpu, IntPtr info);

        const int PS_BASE = 20, PS_SIZE = 456, CLK_BASE = 8, CLK_SIZE = 44, BUF_SIZE = 7416;
        static readonly uint[] Versions = new uint[] { 0x11C94, 0x21CF8, 0x31CF8 };

        static IntPtr gpu = IntPtr.Zero;
        static DPstates getPs, setPs;
        static DPstates ppGetInfo, ppGetStatus, ppSetStatus;   // client power policies (power target %)
        const int PP_INFO_SIZE = 184, PP_STATUS_SIZE = 72;
        static int verIdx = 0;
        public static bool Ready;
        public static void Reset() { Ready = false; gpu = IntPtr.Zero; }
        public static string LastError = "";

        static Delegate Fn(uint id, Type t)
        {
            IntPtr p = QueryInterface(id);
            if (p == IntPtr.Zero) return null;
            return Marshal.GetDelegateForFunctionPointer(p, t);
        }

        public static bool Init()
        {
            try
            {
                DInit init = (DInit)Fn(0x0150E828, typeof(DInit));
                if (init == null) { LastError = "NvAPI_Initialize missing"; return false; }
                int st = init();
                if (st != 0) { LastError = "NvAPI_Initialize " + st; return false; }
                DEnum en = (DEnum)Fn(0xE5AC921F, typeof(DEnum));
                IntPtr[] h = new IntPtr[64]; int n;
                st = en(h, out n);
                if (st != 0 || n < 1) { LastError = "EnumPhysicalGPUs " + st; return false; }
                gpu = h[0];
                getPs = (DPstates)Fn(0x6FF81213, typeof(DPstates));
                setPs = (DPstates)Fn(0x0F4DAE6B, typeof(DPstates));
                if (getPs == null || setPs == null) { LastError = "Pstates20 API missing"; return false; }
                ppGetInfo = (DPstates)Fn(0x34206D86, typeof(DPstates));
                ppGetStatus = (DPstates)Fn(0x70916171, typeof(DPstates));
                ppSetStatus = (DPstates)Fn(0xAD95F5ED, typeof(DPstates));
                Ready = true;
                return true;
            }
            catch (Exception ex) { LastError = ex.Message; return false; }
        }

        static void Zero(IntPtr p)
        {
            byte[] z = new byte[BUF_SIZE];
            Marshal.Copy(z, 0, p, BUF_SIZE);
        }

        public static OffsetInfo GetOffsets()
        {
            OffsetInfo r = new OffsetInfo();
            if (!Ready) return r;
            IntPtr buf = Marshal.AllocHGlobal(BUF_SIZE);
            try
            {
                int st = -1;
                for (int i = 0; i < Versions.Length; i++)
                {
                    Zero(buf);
                    Marshal.WriteInt32(buf, 0, unchecked((int)Versions[i]));
                    st = getPs(gpu, buf);
                    if (st == 0) { verIdx = i; break; }
                }
                r.Status = st;
                if (st != 0) return r;
                int numPs = Marshal.ReadInt32(buf, 8);
                int numClk = Marshal.ReadInt32(buf, 12);
                if (numPs > 16) numPs = 16;
                if (numClk > 8) numClk = 8;
                for (int p = 0; p < numPs; p++)
                {
                    int ps = PS_BASE + p * PS_SIZE;
                    if (Marshal.ReadInt32(buf, ps) != 0) continue; // P0 only
                    for (int c = 0; c < numClk; c++)
                    {
                        int o = ps + CLK_BASE + c * CLK_SIZE;
                        int dom = Marshal.ReadInt32(buf, o);
                        bool ed = (Marshal.ReadInt32(buf, o + 8) & 1) != 0;
                        int val = Marshal.ReadInt32(buf, o + 12) / 1000;
                        int mn = Marshal.ReadInt32(buf, o + 16) / 1000;
                        int mx = Marshal.ReadInt32(buf, o + 20) / 1000;
                        int freq = Marshal.ReadInt32(buf, o + 24) / 1000;
                        if (dom == 0) { r.CoreFound = true; r.CoreEditable = ed; r.CoreMHz = val; r.CoreMin = mn; r.CoreMax = mx; r.CoreBaseMHz = freq; }
                        else if (dom == 4) { r.MemFound = true; r.MemEditable = ed; r.MemMHz = val; r.MemMin = mn; r.MemMax = mx; r.MemBaseMHz = freq; }
                    }
                }
                return r;
            }
            catch (Exception ex) { LastError = ex.Message; r.Status = -1; return r; }
            finally { Marshal.FreeHGlobal(buf); }
        }

        // domain 0 = graphics, 4 = memory. Returns NVAPI status (0 = OK)
        public static int SetOffset(int domain, int mhz)
        {
            if (!Ready) return -1;
            IntPtr buf = Marshal.AllocHGlobal(BUF_SIZE);
            try
            {
                int st = -1;
                for (int k = 0; k < Versions.Length; k++)
                {
                    int i = (verIdx + k) % Versions.Length;
                    Zero(buf);
                    Marshal.WriteInt32(buf, 0, unchecked((int)Versions[i]));
                    Marshal.WriteInt32(buf, 8, 1);  // numPstates
                    Marshal.WriteInt32(buf, 12, 1); // numClocks
                    Marshal.WriteInt32(buf, 16, 0); // numBaseVoltages
                    int ps = PS_BASE;
                    Marshal.WriteInt32(buf, ps, 0); // P0
                    int o = ps + CLK_BASE;
                    Marshal.WriteInt32(buf, o, domain);
                    Marshal.WriteInt32(buf, o + 4, 0);
                    Marshal.WriteInt32(buf, o + 12, mhz * 1000);
                    st = setPs(gpu, buf);
                    if (st != -9) break; // -9 = incompatible struct version
                }
                return st;
            }
            catch (Exception ex) { LastError = ex.Message; return -1; }
            finally { Marshal.FreeHGlobal(buf); }
        }

        static IntPtr Alloc(int size)
        {
            IntPtr p = Marshal.AllocHGlobal(size);
            Marshal.Copy(new byte[size], 0, p, size);
            return p;
        }

        // power target in percent of the default limit (what MSI Afterburner calls "Power Limit %")
        public static PowerPolicy GetPowerPolicy()
        {
            PowerPolicy r = new PowerPolicy();
            if (!Ready || ppGetInfo == null) return r;
            IntPtr info = Alloc(PP_INFO_SIZE), st = Alloc(PP_STATUS_SIZE);
            try
            {
                Marshal.WriteInt32(info, 0, PP_INFO_SIZE | (1 << 16));
                r.InfoStatus = ppGetInfo(gpu, info);
                if (r.InfoStatus == 0 && Marshal.ReadByte(info, 5) >= 1)
                {
                    r.MinPct = Marshal.ReadInt32(info, 8 + 12) / 1000.0;
                    r.DefPct = Marshal.ReadInt32(info, 8 + 24) / 1000.0;
                    r.MaxPct = Marshal.ReadInt32(info, 8 + 36) / 1000.0;
                }
                if (ppGetStatus != null)
                {
                    Marshal.WriteInt32(st, 0, PP_STATUS_SIZE | (1 << 16));
                    r.StatusStatus = ppGetStatus(gpu, st);
                    if (r.StatusStatus == 0 && Marshal.ReadInt32(st, 4) >= 1) r.CurPct = Marshal.ReadInt32(st, 8 + 8) / 1000.0;
                }
                r.Valid = r.InfoStatus == 0 && ppSetStatus != null && r.MaxPct > 0 && r.MaxPct >= r.MinPct && r.MaxPct < 1000;
            }
            catch (Exception ex) { LastError = ex.Message; }
            finally { Marshal.FreeHGlobal(info); Marshal.FreeHGlobal(st); }
            return r;
        }

        public static int SetPowerTarget(double pct)
        {
            if (!Ready || ppSetStatus == null) return -104;
            IntPtr st = Alloc(PP_STATUS_SIZE);
            try
            {
                Marshal.WriteInt32(st, 0, PP_STATUS_SIZE | (1 << 16));
                Marshal.WriteInt32(st, 4, 1);                                   // one entry
                Marshal.WriteInt32(st, 8, 0);                                   // P0
                Marshal.WriteInt32(st, 8 + 8, (int)Math.Round(pct * 1000.0));   // per cent mille
                return ppSetStatus(gpu, st);
            }
            catch (Exception ex) { LastError = ex.Message; return -1; }
            finally { Marshal.FreeHGlobal(st); }
        }

        public static string StatusText(int st)
        {
            switch (st)
            {
                case 0: return "OK";
                case -1: return string.Format(L.T("error ({0})"), LastError);
                case -5: return L.T("invalid argument / out of range");
                case -6: return L.T("NVIDIA GPU not found");
                case -9: return L.T("incompatible structure version");
                case -104: return L.T("not supported by this GPU/vBIOS");
                case -137: return L.T("no permission");
                default: return "NVAPI " + st;
            }
        }
    }

    // ------------------------------------------------------------- fan control
    public class CurvePoint : INotifyPropertyChanged
    {
        int temp, pct;
        public event PropertyChangedEventHandler PropertyChanged;
        public CurvePoint() { }
        public CurvePoint(int t, int p) { temp = Clamp(t, 0, 110); pct = Clamp(p, 0, 100); }
        static int Clamp(int v, int a, int b) { return v < a ? a : (v > b ? b : v); }
        public int Temp
        {
            get { return temp; }
            set { int v = Clamp(value, 0, 110); if (v != temp) { temp = v; Raise("Temp"); } }
        }
        public int Pct
        {
            get { return pct; }
            set { int v = Clamp(value, 0, 100); if (v != pct) { pct = v; Raise("Pct"); } }
        }
        void Raise(string n) { PropertyChangedEventHandler h = PropertyChanged; if (h != null) h(this, new PropertyChangedEventArgs(n)); }
    }

    public class FanChannel
    {
        public int Index;
        public string Name = "";
        public int Mode;          // 0 = EC auto, 1 = curve, 2 = fixed
        public int Source;        // 0 = CPU, 1 = GPU, 2 = max(CPU, GPU)
        public int Fixed = 60;
        public ObservableCollection<CurvePoint> Points = new ObservableCollection<CurvePoint>();

        public bool Present;
        public int Rpm;
        public double DutyPct = double.NaN;
        public double EcTemp = double.NaN;
        public double InputTemp = double.NaN;
        public double EffTemp = double.NaN;
        public double LoadEma = double.NaN;
        public bool IsLoad { get { return Source >= 3; } }
        public double CurPct = double.NaN;
        public bool Manual;
        public int LastRaw = -1;
        public DateTime LastWrite = DateTime.MinValue;
        public string Status = "";
        public bool InfoCmd = true;
    }

    public class Hw : IDisposable
    {
        [StructLayout(LayoutKind.Sequential)]
        struct MemStatus
        {
            public uint Length; public uint Load;
            public ulong TotalPhys, AvailPhys, TotalPage, AvailPage, TotalVirt, AvailVirt, AvailExt;
        }
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern bool GlobalMemoryStatusEx(ref MemStatus m);

        public ClevoEc Ec;
        public IntelMsr Msr;
        public string EcError = "", MsrError = "", NvmlError = "";
        public bool NvmlOk;
        IntPtr dev = IntPtr.Zero;
        public string GpuName = "NVIDIA GPU", Driver = "";
        public double DefaultPowerW = double.NaN, MinPowerW = double.NaN, MaxPowerW = double.NaN;

        public double CpuTemp = double.NaN, CpuPower = double.NaN, CpuLoad = double.NaN, CpuClock = double.NaN;
        public double RamUsed = double.NaN, RamTotal = double.NaN;
        public double GpuTemp = double.NaN, GpuClock = double.NaN, MemClock = double.NaN, GpuLoad = double.NaN;
        public double GpuPower = double.NaN, GpuPowerLimit = double.NaN, VramUsed = double.NaN, VramTotal = double.NaN;

        public List<FanChannel> Fans = new List<FanChannel>();
        public bool GpuTempFromEc;
        public double Hysteresis = 3, DownRate = 3, FailsafeTemp = 92, LoadSmoothSec = 3;
        public bool FailsafeActive;
        public List<string> Messages = new List<string>();

        int tjMax = 100;
        double energyUnit = double.NaN;
        uint lastEnergy; long lastEnergyTicks; bool energyInit;
        Pdh pdh;
        double baseMhz;

        public Hw(string ecModule, string msrModule, double baseClockMhz)
        {
            baseMhz = baseClockMhz > 0 ? baseClockMhz : 3700;
            try { pdh = new Pdh(); } catch (Exception ex) { Msg("PDH: " + ex.Message); }

            Fans.Add(new FanChannel { Index = 1, Name = "CPU", Source = 0 });
            Fans.Add(new FanChannel { Index = 2, Name = "GPU", Source = 1 });

            bool driver = false;
            try { driver = PawnIo.DriverPresent(); } catch { }

            if (!driver) { EcError = MsrError = "PawnIO driver not installed"; }
            else
            {
                if (ecModule != null && File.Exists(ecModule))
                {
                    try { Ec = new ClevoEc(File.ReadAllBytes(ecModule)); }
                    catch (Exception ex) { EcError = ex.Message; Ec = null; }
                }
                else EcError = "LpcACPIEC.bin not found";

                if (msrModule != null && File.Exists(msrModule))
                {
                    try
                    {
                        Msr = new IntelMsr(File.ReadAllBytes(msrModule));
                        ulong tt = Msr.Read(0x1A2);
                        int tj = (int)((tt >> 16) & 0xFF);
                        if (tj >= 70 && tj <= 115) tjMax = tj;
                        ulong units = Msr.Read(0x606);
                        energyUnit = 1.0 / Math.Pow(2, (double)((units >> 8) & 0x1F));
                    }
                    catch (Exception ex) { MsrError = ex.Message; Msr = null; }
                }
                else MsrError = "IntelMSR.bin not found";
            }

            if (Ec != null) DetectFans();

            try
            {
                int st = Nvml.Init();
                if (st == 0) st = Nvml.GetHandle(0, out dev);
                if (st == 0)
                {
                    NvmlOk = true;
                    StringBuilder sb = new StringBuilder(96);
                    if (Nvml.GetName(dev, sb, 96) == 0) GpuName = sb.ToString();
                    sb = new StringBuilder(80);
                    if (Nvml.GetDriver(sb, 80) == 0) Driver = sb.ToString();
                    uint a, b;
                    if (Nvml.GetDefaultLimit(dev, out a) == 0) DefaultPowerW = a / 1000.0;
                    if (Nvml.GetLimitConstraints(dev, out a, out b) == 0) { MinPowerW = a / 1000.0; MaxPowerW = b / 1000.0; }
                }
                else NvmlError = Nvml.ErrorString(st);
            }
            catch (Exception ex) { NvmlError = ex.Message; }

            NvApi.Init();
        }

        void Msg(string s)
        {
            lock (Messages) { Messages.Add(s); }
        }

        public string[] TakeMessages()
        {
            lock (Messages) { string[] a = Messages.ToArray(); Messages.Clear(); return a; }
        }

        public void DetectFans()
        {
            foreach (FanChannel f in Fans)
            {
                int rpm = -1, duty = -1;
                f.InfoCmd = true;
                try { duty = Ec.FanInfo(f.Index)[2]; }
                catch { f.InfoCmd = false; }
                try { rpm = Ec.FanRpm(f.Index); } catch { rpm = -1; }
                f.Present = f.InfoCmd || rpm >= 0;
            }
        }

        public bool PowerLimitSupported
        {
            get { return NvmlOk && !double.IsNaN(MinPowerW) && !double.IsNaN(MaxPowerW) && MaxPowerW - MinPowerW >= 1; }
        }

        public int SetPowerLimitW(double w) { return NvmlOk ? Nvml.SetPowerLimit(dev, (uint)Math.Round(w * 1000)) : 999; }
        public int LockClocks(int minMhz, int maxMhz) { return NvmlOk ? Nvml.SetLockedClocks(dev, (uint)minMhz, (uint)maxMhz) : 999; }
        public int ResetClocks() { return NvmlOk ? Nvml.ResetLockedClocks(dev) : 999; }
        public string NvmlText(int st) { return st == 999 ? L.T("NVML unavailable") : (st == 0 ? "OK" : Nvml.ErrorString(st)); }

        public void Tick(double dtSec)
        {
            ReadCpu();
            ReadRam();
            ReadGpu();
            ReadFans();
            if (double.IsNaN(GpuTemp) && Fans.Count > 1) GpuTempFromEc = !double.IsNaN(Fans[1].EcTemp); else GpuTempFromEc = false;
            Control(dtSec);
        }

        void ReadCpu()
        {
            if (pdh != null)
            {
                double load, perf;
                pdh.Collect(out load, out perf);
                CpuLoad = double.IsNaN(load) ? double.NaN : Math.Max(0, Math.Min(100, load));
                CpuClock = double.IsNaN(perf) ? double.NaN : baseMhz * perf / 100.0;
            }
            if (Msr != null)
            {
                try
                {
                    ulong ts = Msr.Read(0x1B1);
                    CpuTemp = tjMax - (int)((ts >> 16) & 0x7F);
                    uint e = (uint)(Msr.Read(0x611) & 0xFFFFFFFF);
                    long now = Stopwatch.GetTimestamp();
                    if (energyInit)
                    {
                        double dt = (now - lastEnergyTicks) / (double)Stopwatch.Frequency;
                        uint de = unchecked(e - lastEnergy);
                        if (dt > 0.05) CpuPower = de * energyUnit / dt;
                    }
                    lastEnergy = e; lastEnergyTicks = now; energyInit = true;
                }
                catch (Exception ex) { CpuTemp = double.NaN; CpuPower = double.NaN; Msg("MSR: " + ex.Message); }
            }
            else
            {
                CpuTemp = (Fans.Count > 0) ? Fans[0].EcTemp : double.NaN;
            }
        }

        void ReadRam()
        {
            MemStatus m = new MemStatus();
            m.Length = (uint)Marshal.SizeOf(typeof(MemStatus));
            if (GlobalMemoryStatusEx(ref m))
            {
                RamTotal = m.TotalPhys / 1073741824.0;
                RamUsed = (m.TotalPhys - m.AvailPhys) / 1073741824.0;
            }
        }

        int nvmlBadTicks;
        DateTime nvmlLastReinit = DateTime.MinValue;
        public int NvmlReinits;

        // after a driver/GPU reset the cached NVML handle goes stale and returns errors or garbage
        public bool ReinitNvml()
        {
            try { Nvml.Shutdown(); } catch { }
            NvmlOk = false;
            try
            {
                int st = Nvml.Init();
                if (st == 0) st = Nvml.GetHandle(0, out dev);
                NvmlOk = st == 0;
                if (!NvmlOk) NvmlError = Nvml.ErrorString(st);
                else
                {
                    uint a, b;
                    if (Nvml.GetDefaultLimit(dev, out a) == 0) DefaultPowerW = a / 1000.0;
                    if (Nvml.GetLimitConstraints(dev, out a, out b) == 0) { MinPowerW = a / 1000.0; MaxPowerW = b / 1000.0; }
                }
            }
            catch (Exception ex) { NvmlError = ex.Message; NvmlOk = false; }
            try { NvApi.Reset(); NvApi.Init(); } catch { }
            NvmlReinits++;
            return NvmlOk;
        }

        void ReadGpu()
        {
            if (!NvmlOk)
            {
                if ((DateTime.Now - nvmlLastReinit).TotalSeconds >= 30) { nvmlLastReinit = DateTime.Now; if (ReinitNvml()) Msg("NVML: GPU found again"); }
                if (!NvmlOk) { GpuTemp = GpuClock = MemClock = GpuPower = GpuLoad = double.NaN; return; }
            }
            uint v;
            int stT = Nvml.GetTemp(dev, 0, out v);
            GpuTemp = (stT == 0 && v > 0 && v < 125) ? v : double.NaN;
            int stC = Nvml.GetClock(dev, 0, out v);
            GpuClock = (stC == 0 && v < 4000) ? v : double.NaN;
            int stM = Nvml.GetClock(dev, 2, out v);
            MemClock = (stM == 0 && v < 20000) ? v : double.NaN;
            int stP = Nvml.GetPower(dev, out v);
            GpuPower = (stP == 0 && v < 1000000) ? v / 1000.0 : double.NaN;
            GpuPowerLimit = (Nvml.GetEnforcedLimit(dev, out v) == 0 && v > 0 && v < 1000000) ? v / 1000.0 : double.NaN;
            Nvml.Util u;
            int stU = Nvml.GetUtil(dev, out u);
            GpuLoad = (stU == 0 && u.Gpu <= 100) ? u.Gpu : double.NaN;
            Nvml.Mem mm;
            if (Nvml.GetMem(dev, out mm) == 0) { VramTotal = mm.Total / 1073741824.0; VramUsed = mm.Used / 1073741824.0; }

            // temperature and clock both unusable for 3 reads in a row: reconnect (at most every 30 s)
            bool bad = double.IsNaN(GpuTemp) && double.IsNaN(GpuClock);
            nvmlBadTicks = bad ? nvmlBadTicks + 1 : 0;
            if (nvmlBadTicks >= 3 && (DateTime.Now - nvmlLastReinit).TotalSeconds >= 30)
            {
                nvmlLastReinit = DateTime.Now;
                nvmlBadTicks = 0;
                Msg(string.Format("NVML: invalid readings (temp {0}, clock {1}, power {2}, load {3}) - reconnecting to the GPU", stT, stC, stP, stU));
                if (ReinitNvml()) Msg("NVML: reconnected"); else Msg("NVML: " + NvmlError);
            }
        }

        void ReadFans()
        {
            if (Ec == null) return;
            foreach (FanChannel f in Fans)
            {
                if (!f.Present) continue;
                try
                {
                    if (f.InfoCmd)
                    {
                        int[] info = Ec.FanInfo(f.Index);
                        f.EcTemp = (info[0] > 0 && info[0] < 120) ? info[0] : double.NaN;
                        f.DutyPct = Math.Round(info[2] * 100.0 / 255.0);
                    }
                    else
                    {
                        f.DutyPct = Math.Round(Ec.ReadReg(0xCE + f.Index - 1) * 100.0 / 255.0);
                    }
                    f.Rpm = Ec.FanRpm(f.Index);
                }
                catch (Exception ex) { f.DutyPct = double.NaN; f.Status = ex.Message; }
            }
        }

        public static double Interp(IList<CurvePoint> pts, double t)
        {
            if (pts == null || pts.Count == 0) return double.NaN;
            List<CurvePoint> s = new List<CurvePoint>(pts);
            s.Sort(delegate (CurvePoint a, CurvePoint b) { return a.Temp.CompareTo(b.Temp); });
            if (t <= s[0].Temp) return s[0].Pct;
            if (t >= s[s.Count - 1].Temp) return s[s.Count - 1].Pct;
            for (int i = 0; i < s.Count - 1; i++)
            {
                CurvePoint a = s[i], b = s[i + 1];
                if (t >= a.Temp && t <= b.Temp)
                {
                    if (b.Temp == a.Temp) return Math.Max(a.Pct, b.Pct);
                    return a.Pct + (b.Pct - a.Pct) * (t - a.Temp) / (double)(b.Temp - a.Temp);
                }
            }
            return s[s.Count - 1].Pct;
        }

        // sources: 0 CPU temp, 1 GPU temp, 2 max temp, 3 CPU load, 4 GPU load, 5 max load
        double SourceValue(FanChannel f, double dt)
        {
            if (f.Source >= 3)
            {
                double cl = CpuLoad, gl = GpuLoad, v;
                if (f.Source == 3) v = cl;
                else if (f.Source == 4) v = gl;
                else if (double.IsNaN(cl)) v = gl;
                else if (double.IsNaN(gl)) v = cl;
                else v = Math.Max(cl, gl);
                if (double.IsNaN(v)) { f.LoadEma = double.NaN; return v; }
                if (double.IsNaN(f.LoadEma) || LoadSmoothSec <= 0) f.LoadEma = v;
                else f.LoadEma += (v - f.LoadEma) * Math.Min(1.0, dt / LoadSmoothSec);
                return f.LoadEma;
            }
            double c = !double.IsNaN(CpuTemp) ? CpuTemp : (Fans.Count > 0 ? Fans[0].EcTemp : double.NaN);
            double g = !double.IsNaN(GpuTemp) ? GpuTemp : (Fans.Count > 1 ? Fans[1].EcTemp : double.NaN);
            if (f.Source == 0) return c;
            if (f.Source == 1) return g;
            if (double.IsNaN(c)) return g;
            if (double.IsNaN(g)) return c;
            return Math.Max(c, g);
        }

        void Control(double dt)
        {
            if (Ec == null) return;
            double hot = double.NaN;
            if (!double.IsNaN(CpuTemp)) hot = CpuTemp;
            double gT = !double.IsNaN(GpuTemp) ? GpuTemp : (Fans.Count > 1 ? Fans[1].EcTemp : double.NaN);   // EC fallback keeps the safety check working
            if (!double.IsNaN(gT)) hot = double.IsNaN(hot) ? gT : Math.Max(hot, gT);
            bool fs = !double.IsNaN(hot) && hot >= FailsafeTemp;
            if (fs && !FailsafeActive) Msg(string.Format(L.T("Safety: {0} \u00b0C \u2265 {1} \u00b0C \u2192 fans at 100%"), hot.ToString("0"), FailsafeTemp.ToString("0")));
            FailsafeActive = fs;

            foreach (FanChannel f in Fans)
            {
                if (!f.Present) continue;
                try
                {
                    if (f.Mode == 0)
                    {
                        if (f.Manual) { Ec.SetAuto(f.Index); f.Manual = false; f.LastRaw = -1; f.CurPct = double.NaN; f.EffTemp = double.NaN; f.LoadEma = double.NaN; }
                        f.Status = "EC auto";
                        continue;
                    }
                    double t = SourceValue(f, dt);
                    f.InputTemp = t;
                    double target;
                    if (fs) target = 100;
                    else if (f.Mode == 2) target = f.Fixed;
                    else
                    {
                        if (double.IsNaN(t))
                        {
                            if (f.Manual) { Ec.SetAuto(f.Index); f.Manual = false; f.LastRaw = -1; }
                            f.Status = "sem sensor \u2192 EC auto";
                            continue;
                        }
                        if (double.IsNaN(f.EffTemp) || t >= f.EffTemp) f.EffTemp = t;
                        else if (t <= f.EffTemp - Hysteresis) f.EffTemp = t + Hysteresis;
                        target = Interp(f.Points, f.EffTemp);
                        if (double.IsNaN(target)) target = 100;
                    }
                    if (double.IsNaN(f.CurPct) || target >= f.CurPct || fs) f.CurPct = target;
                    else f.CurPct = Math.Max(target, f.CurPct - DownRate * dt);

                    int raw = (int)Math.Round(f.CurPct * 2.55);
                    if (raw < 1) raw = 1;
                    if (raw > 255) raw = 255;
                    if (raw != f.LastRaw || (DateTime.Now - f.LastWrite).TotalSeconds >= 3)
                    {
                        Ec.SetDuty(f.Index, raw);
                        f.LastRaw = raw; f.LastWrite = DateTime.Now; f.Manual = true;
                    }
                    f.Status = fs ? "SEGURAN\u00c7A 100%" : (f.Mode == 2 ? "fixo" : "curva");
                }
                catch (Exception ex) { f.Status = "erro: " + ex.Message; Msg(string.Format(L.T("Fan {0}: {1}"), f.Name, ex.Message)); }
            }
        }

        public void ReleaseAll()
        {
            if (Ec == null) return;
            foreach (FanChannel f in Fans)
            {
                if (!f.Present) continue;
                for (int i = 0; i < 2; i++)
                {
                    try { Ec.SetAuto(f.Index); break; } catch { Thread.Sleep(20); }
                }
                f.Manual = false; f.LastRaw = -1; f.CurPct = double.NaN; f.EffTemp = double.NaN;
            }
        }

        public void Dispose()
        {
            try { ReleaseAll(); } catch { }
            if (Ec != null) Ec.Dispose();
            if (Msr != null) Msr.Dispose();
            if (pdh != null) pdh.Dispose();
            try { if (NvmlOk) Nvml.Shutdown(); } catch { }
        }
    }

    // ---------------------------------------------------------------- helpers
    public static class Win
    {
        [DllImport("user32.dll")] static extern int GetWindowLong(IntPtr h, int i);
        [DllImport("user32.dll")] static extern int SetWindowLong(IntPtr h, int i, int v);
        public static void ClickThrough(IntPtr h)
        {
            int ex = GetWindowLong(h, -20);
            SetWindowLong(h, -20, ex | 0x20 | 0x80000 | 0x80); // TRANSPARENT | LAYERED | TOOLWINDOW
        }
    }
}

'@

try {
    if (-not ('ClevoTune.Hw' -as [type])) {
        $sha  = New-Object System.Security.Cryptography.SHA1Managed
        $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($CoreSource))).Replace('-', '').Substring(0, 12)
        $dll  = Join-Path $CacheDir "core-$hash.dll"
        if (-not (Test-Path -LiteralPath $dll)) {
            Get-ChildItem -LiteralPath $CacheDir -Filter 'core-*.dll' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            Add-Type -TypeDefinition $CoreSource -OutputAssembly $dll -OutputType Library
        }
        if (-not ('ClevoTune.Hw' -as [type])) { Add-Type -LiteralPath $dll }
    }
} catch {
    [System.Windows.MessageBox]::Show("$(T 'Failed to compile the core:')`n`n$($_.Exception.Message)", $AppName, 'OK', 'Error') | Out-Null
    return
}

# ---------------------------------------------------------------- log (buffered until UI exists)
$ProgressPreference = 'SilentlyContinue'
$ui = $null
$script:PendingLog = New-Object 'System.Collections.Generic.List[string]'
function Log([string]$m) {
    $line = '[{0:HH:mm:ss}] {1}' -f (Get-Date), $m
    if ($ui -and $ui.TxtLog) { try { $ui.TxtLog.AppendText($line + "`r`n"); $ui.TxtLog.ScrollToEnd() } catch { } }
    else { $script:PendingLog.Add($line) }
    try {
        if ((Test-Path -LiteralPath $LogPath) -and (Get-Item -LiteralPath $LogPath).Length -gt 512KB) { Remove-Item -LiteralPath $LogPath -Force }
        [IO.File]::AppendAllText($LogPath, $line + "`r`n")
    } catch { }
}
foreach ($n in $script:LangNotes) { Log $n }

# ---------------------------------------------------------------- config
function New-Pts($pairs) {
    $o = @()
    for ($i = 0; $i -lt $pairs.Count; $i += 2) { $o += [pscustomobject]@{ t = $pairs[$i]; p = $pairs[$i + 1] } }
    return , $o
}
$LoadPresets = @{
    0 = @(0, 20, 25, 25, 50, 35, 75, 55, 100, 75)
    1 = @(0, 25, 20, 30, 40, 45, 60, 60, 80, 80, 100, 95)
    2 = @(0, 35, 20, 45, 40, 60, 60, 75, 80, 90, 100, 100)
    3 = @(0, 100, 100, 100)
}
$Presets = @{
    0 = @(45, 25, 55, 35, 65, 50, 75, 70, 85, 100)
    1 = @(40, 30, 50, 40, 60, 55, 70, 70, 80, 85, 88, 100)
    2 = @(35, 40, 45, 55, 55, 70, 65, 85, 75, 100)
    3 = @(30, 100, 100, 100)
}

function New-DefaultConfig {
    [pscustomobject]@{
        selectedProfile = 'Stock'
        autoApply       = $false
        applyOnOpen     = $true
        lastProfile     = ''
        profiles        = @([pscustomobject]@{ name = 'Stock'; power = 0; core = 0; mem = 0; lock = 0 })
        fans            = @(
            [pscustomobject]@{ index = 1; mode = 0; source = 0; fixed = 60; points = (New-Pts $Presets[1]) },
            [pscustomobject]@{ index = 2; mode = 0; source = 1; fixed = 60; points = (New-Pts $Presets[1]) }
        )
        hyst        = 3
        down        = 3
        failsafe    = 92
        interval    = 1000
        closeToTray = $true
        cfcGrid     = $false
        powerLocked = ''
        mvoltPath   = ''
        mvoltChecked = ''
        powerMax    = ''
        lastVolt    = 0
        lang        = 'auto'
        loadSmooth  = 3
        lastLock    = 0
        overlay     = [pscustomobject]@{ enabled = $false; pos = 1; font = 14; opacity = 55; cpu = $true; gpu = $true; clk = $true; fan = $true; mem = $false }
    }
}

function Merge-Defaults($cfg, $def) {
    foreach ($p in $def.PSObject.Properties) {
        if (-not ($cfg.PSObject.Properties.Name -contains $p.Name)) {
            $cfg | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value
        } elseif ($p.Value -is [pscustomobject] -and $cfg.($p.Name) -is [pscustomobject]) {
            Merge-Defaults $cfg.($p.Name) $p.Value
        }
    }
}

function Load-Config {
    $def = New-DefaultConfig
    if (Test-Path -LiteralPath $CfgPath) {
        try {
            $c = Get-Content -LiteralPath $CfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
            Merge-Defaults $c $def
            $c.profiles = @($c.profiles)
            $c.fans = @($c.fans)
            $c.fans = @($c.fans | Where-Object { [int]$_.index -le 2 })
            foreach ($f in $c.fans) { $f.points = @($f.points) }
            if ($c.profiles.Count -eq 0) { $c.profiles = $def.profiles }
            return $c
        } catch { }
    }
    return $def
}

$script:FirstRun = -not (Test-Path -LiteralPath $CfgPath)
$script:Cfg = Load-Config
Set-Lang (Resolve-Lang ([string]$script:Cfg.lang))
$script:Dirty = $false
$script:LastSave = [DateTime]::MinValue

function Save-Config {
    try {
        $fans = @()
        foreach ($f in $script:Hw.Fans) {
            $pts = @()
            foreach ($p in $f.Points) { $pts += [pscustomobject]@{ t = $p.Temp; p = $p.Pct } }
            $fans += [pscustomobject]@{ index = $f.Index; mode = $f.Mode; source = $f.Source; fixed = $f.Fixed; points = $pts }
        }
        $script:Cfg.fans = $fans
        $json = $script:Cfg | ConvertTo-Json -Depth 8
        [IO.File]::WriteAllText($CfgPath, $json, (New-Object Text.UTF8Encoding($false)))
        $script:Dirty = $false
        $script:LastSave = Get-Date
    } catch { Log ((T 'Error saving settings: {0}') -f $_.Exception.Message) }
}

# ---------------------------------------------------------------- system info
$CpuName = 'CPU'; $BaseMhz = 3700; $Model = ''
try {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $CpuName = ($cpu.Name -replace '\s+', ' ').Trim()
    if ($cpu.MaxClockSpeed -gt 0) { $BaseMhz = [double]$cpu.MaxClockSpeed }
    $Model = (Get-CimInstance Win32_ComputerSystem).Model
} catch { }

# ---------------------------------------------------------------- automatic dependencies (PawnIO driver + modules)
$PawnSetupUrl = 'https://github.com/namazso/PawnIO.Setup/releases/latest/download/PawnIO_setup.exe'
$script:RebootNeeded = $false

function Test-PawnDriver { try { return [ClevoTune.PawnIo]::DriverPresent() } catch { return $false } }
function Test-PawnInstalled {
    foreach ($k in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO') {
        if (Test-Path $k) { return $true }
    }
    return $false
}

function Get-ModTargetDir {
    try {
        if (-not (Test-Path -LiteralPath $ModDir)) { New-Item -ItemType Directory -Path $ModDir -Force | Out-Null }
        $probe = Join-Path $ModDir '.write-test'
        [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force
        return $ModDir
    } catch {
        $d = Join-Path $DataDir 'modules'
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        return $d
    }
}

function Invoke-Download([string]$url, [string]$out) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -Headers @{ 'User-Agent' = 'ClevoTune' } -TimeoutSec 60
}

function Install-PawnIO {
    $tmp = Join-Path $env:TEMP ('PawnIO_setup-' + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        Invoke-Download $PawnSetupUrl $tmp
        $sig = Get-AuthenticodeSignature -LiteralPath $tmp
        if ($sig.Status -ne 'Valid') { throw ((T 'invalid installer signature ({0})') -f $sig.Status) }
        Log ((T 'PawnIO installer verified: {0}') -f $sig.SignerCertificate.Subject)
        $p = Start-Process -FilePath $tmp -ArgumentList '-install', '-silent' -Wait -PassThru
        switch ($p.ExitCode) {
            0       { Log (T 'PawnIO driver installed') }
            3010    { Log (T 'PawnIO driver installed — Windows requests a restart'); $script:RebootNeeded = $true }
            default { throw ((T 'the PawnIO installer exited with code {0}') -f $p.ExitCode) }
        }
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

function Get-ModulesZipUrl {
    $hdr = @{ 'User-Agent' = 'ClevoTune' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/namazso/PawnIO.Modules/releases/latest' -Headers $hdr -UseBasicParsing -TimeoutSec 30
        $asset = @($rel.assets | Where-Object { $_.name -like '*.zip' }) | Select-Object -First 1
        if ($asset) { return @($asset.browser_download_url, $rel.tag_name) }
    } catch { Log ((T 'GitHub API unavailable ({0}), trying the releases page') -f $_.Exception.Message) }
    # fallback without the API (rate limit): follow /releases/latest and read the asset list
    $r = Invoke-WebRequest -Uri 'https://github.com/namazso/PawnIO.Modules/releases/latest' -Headers $hdr -UseBasicParsing -TimeoutSec 30
    $tag = ($r.BaseResponse.ResponseUri.AbsoluteUri -split '/')[-1]
    $page = Invoke-WebRequest -Uri "https://github.com/namazso/PawnIO.Modules/releases/expanded_assets/$tag" -Headers $hdr -UseBasicParsing -TimeoutSec 30
    $m = [regex]::Match($page.Content, 'href="(/namazso/PawnIO\.Modules/releases/download/[^"]+?\.zip)"')
    if (-not $m.Success) { throw (T 'could not find the modules .zip in the latest release') }
    return @(('https://github.com' + $m.Groups[1].Value), $tag)
}

function Install-Modules {
    $info = Get-ModulesZipUrl
    $tmp = Join-Path $env:TEMP ('clevotune-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $zip = Join-Path $tmp 'modules.zip'
        Invoke-Download $info[0] $zip
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $x = Join-Path $tmp 'x'
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $x)
        $dest = Get-ModTargetDir
        $got = 0
        foreach ($n in 'LpcACPIEC.bin', 'IntelMSR.bin') {
            $f = Get-ChildItem -LiteralPath $x -Recurse -Filter $n | Where-Object { $_.FullName -notmatch '(?i)arm' } | Select-Object -First 1
            if ($f) {
                Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $dest $n) -Force
                $shared = Join-Path $DataDir 'modules'
                if ($dest -ne $shared) { try { if (-not (Test-Path -LiteralPath $shared)) { New-Item -ItemType Directory -Path $shared -Force | Out-Null }; Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $shared $n) -Force } catch { } }
                Log ((T 'Module {0} installed ({1})') -f $n, $info[1]); $got++
            }
            else { Log ((T 'Module {0} not found in the zip ({1})') -f $n, $info[1]) }
        }
        return $got
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

# small progress window (the console is hidden)
$script:Splash = $null
function Show-Splash([string]$text) {
    if (-not $script:Splash) {
        $w = New-Object System.Windows.Window
        $w.WindowStyle = 'None'; $w.ResizeMode = 'NoResize'; $w.SizeToContent = 'WidthAndHeight'; $w.Topmost = $true
        $w.WindowStartupLocation = 'CenterScreen'; $w.ShowInTaskbar = $true; $w.Title = 'ClevoTune'
        $w.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#15181B')
        $w.BorderBrush = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#45D3B4'); $w.BorderThickness = New-Object System.Windows.Thickness 1
        $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = New-Object System.Windows.Thickness 28, 22, 28, 22; $sp.Width = 380
        $t1 = New-Object System.Windows.Controls.TextBlock; $t1.Text = (T 'ClevoTune — first-time setup'); $t1.FontSize = 15; $t1.FontWeight = 'SemiBold'
        $t1.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#E6E8EA')
        $t2 = New-Object System.Windows.Controls.TextBlock; $t2.Margin = New-Object System.Windows.Thickness 0, 10, 0, 12; $t2.TextWrapping = 'Wrap'
        $t2.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#A9AFB5')
        $pb = New-Object System.Windows.Controls.ProgressBar; $pb.IsIndeterminate = $true; $pb.Height = 4; $pb.BorderThickness = New-Object System.Windows.Thickness 0
        $pb.Foreground = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#45D3B4')
        $pb.Background = (New-Object System.Windows.Media.BrushConverter).ConvertFromString('#2A2F34')
        [void]$sp.Children.Add($t1); [void]$sp.Children.Add($t2); [void]$sp.Children.Add($pb)
        $w.Content = $sp
        $w.Tag = $t2
        $w.Show()
        $script:Splash = $w
    }
    $script:Splash.Tag.Text = $text
    Pump-Ui
}
function Close-Splash { if ($script:Splash) { $script:Splash.Close(); $script:Splash = $null } }
function Pump-Ui {
    $script:UiFrame = New-Object System.Windows.Threading.DispatcherFrame
    [void][System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{ $script:UiFrame.Continue = $false })
    [System.Windows.Threading.Dispatcher]::PushFrame($script:UiFrame)
}

function Ensure-Dependencies([bool]$force) {
    $needDrv = $force -or -not (Test-PawnDriver)
    $needMod = $force -or -not (Find-Module 'LpcACPIEC.bin') -or -not (Find-Module 'IntelMSR.bin')
    if (-not $needDrv -and -not $needMod) { return }
    if (-not $IsAdmin) { Log (T 'Not running as administrator: PawnIO cannot be installed.'); return }
    try {
        if ($needDrv) {
            Show-Splash (T 'Downloading and installing the PawnIO driver (signed)…')
            try { Install-PawnIO } catch { Log ((T 'PawnIO installation failed: {0}') -f $_.Exception.Message) }
            if (-not (Test-PawnDriver) -and -not $script:RebootNeeded -and (Test-PawnInstalled)) {
                Log (T 'PawnIO is installed but the driver is not active yet — a restart may be needed.')
                $script:RebootNeeded = $true
            }
        }
        if ($needMod) {
            Show-Splash (T 'Downloading the PawnIO modules (fan EC and CPU MSR)…')
            try { [void](Install-Modules) } catch { Log ((T 'Module download failed: {0}') -f $_.Exception.Message) }
        }
    } finally { Close-Splash }
}

Ensure-Dependencies $false
try {
    $shared = Join-Path $DataDir 'modules'
    foreach ($n in 'LpcACPIEC.bin', 'IntelMSR.bin') {
        $f = Find-Module $n
        if ($f -and -not (Test-Path -LiteralPath (Join-Path $shared $n))) {
            if (-not (Test-Path -LiteralPath $shared)) { New-Item -ItemType Directory -Path $shared -Force | Out-Null }
            Copy-Item -LiteralPath $f -Destination (Join-Path $shared $n) -Force
        }
    }
} catch { }

# ---------------------------------------------------------------- hardware
function New-HwInstance {
    $ec  = Find-Module 'LpcACPIEC.bin'
    $msr = Find-Module 'IntelMSR.bin'
    $h = New-Object ClevoTune.Hw($ec, $msr, $BaseMhz)
    $h.Hysteresis   = [double]$script:Cfg.hyst
    $h.DownRate     = [double]$script:Cfg.down
    $h.FailsafeTemp = [double]$script:Cfg.failsafe
    $h.LoadSmoothSec = [double]$script:Cfg.loadSmooth
    foreach ($cf in $script:Cfg.fans) {
        $i = [int]$cf.index - 1
        if ($i -lt 0 -or $i -ge $h.Fans.Count) { continue }
        $f = $h.Fans[$i]
        $f.Mode = [int]$cf.mode; $f.Source = [int]$cf.source; $f.Fixed = [int]$cf.fixed
        $f.Points.Clear()
        foreach ($p in $cf.points) { $f.Points.Add((New-Object ClevoTune.CurvePoint([int]$p.t, [int]$p.p))) }
        if ($f.Points.Count -eq 0) { foreach ($q in (New-Pts $Presets[1])) { $f.Points.Add((New-Object ClevoTune.CurvePoint([int]$q.t, [int]$q.p))) } }
    }
    return $h
}
$script:Hw = New-HwInstance

# ---------------------------------------------------------------- mVolt+ (optional, by b00nz) via its command line
function Inv([string]$f, $v) { return [string]::Format([Globalization.CultureInfo]::InvariantCulture, $f, $v) }
function Get-MVoltDir {
    # mVolt+ lives in a mVolt+ folder next to ClevoTune (falls back to %APPDATA% if that folder is read-only)
    $d = Join-Path $SelfDir 'mVolt+'
    try {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        $probe = Join-Path $d '.write-test'
        [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force
        return $d
    } catch {
        $d = Join-Path $DataDir 'mVolt+'
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        return $d
    }
}
function Get-LocalMVolt {
    foreach ($d in (Join-Path $SelfDir 'mVolt+'), (Join-Path $DataDir 'mVolt+')) {
        $f = Join-Path $d 'mVolt+.exe'
        if (Test-Path -LiteralPath $f) { return $f }
    }
    return $null
}
function Get-LocalMVoltVersion([string]$exe) {
    $vf = Join-Path (Split-Path -Parent $exe) 'version.txt'
    if (Test-Path -LiteralPath $vf) { return ([IO.File]::ReadAllText($vf)).Trim() }
    try { $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe).ProductVersion; if ($v) { return $v.Trim() } } catch { }
    return ''
}
function Find-MVolt {
    $l = Get-LocalMVolt
    if ($l) { return $l }
    # fallbacks while the local copy is missing (offline first start)
    $p = [string]$script:Cfg.mvoltPath
    if ($p -and (Test-Path -LiteralPath $p)) { return $p }
    foreach ($root in (Join-Path $env:ProgramFiles 'mVolt+'), (Join-Path $env:LOCALAPPDATA 'mVolt+')) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $f = Get-ChildItem -LiteralPath $root -Recurse -Filter 'mVolt*.exe' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}
function Get-MVoltRelease {
    $hdr = @{ 'User-Agent' = 'ClevoTune' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/b00nz/mVolt/releases/latest' -Headers $hdr -UseBasicParsing -TimeoutSec 20
        $as = @($rel.assets | Where-Object { $_.name -match '(?i)\.exe$' }) + @($rel.assets | Where-Object { $_.name -match '(?i)\.zip$' })
        if ($as.Count -gt 0) { return @{ Tag = [string]$rel.tag_name; Url = [string]$as[0].browser_download_url } }
    } catch { }
    $r = Invoke-WebRequest -Uri 'https://github.com/b00nz/mVolt/releases/latest' -Headers $hdr -UseBasicParsing -TimeoutSec 20
    $tag = ($r.BaseResponse.ResponseUri.AbsoluteUri -split '/')[-1]
    $page = Invoke-WebRequest -Uri "https://github.com/b00nz/mVolt/releases/expanded_assets/$tag" -Headers $hdr -UseBasicParsing -TimeoutSec 20
    $m = [regex]::Match($page.Content, 'href="(/b00nz/mVolt/releases/download/[^"]+?\.(?:exe|zip))"')
    if (-not $m.Success) { throw 'no .exe or .zip in the latest mVolt+ release' }
    return @{ Tag = $tag; Url = ('https://github.com' + $m.Groups[1].Value) }
}
function Install-MVolt($rel) {
    $dir = Get-MVoltDir
    $tmp = Join-Path $dir ('download-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $name = [Uri]::UnescapeDataString(($rel.Url -split '/')[-1])
        $file = Join-Path $tmp $name
        Invoke-Download $rel.Url $file
        if ($file -match '(?i)\.zip$') {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $x = Join-Path $tmp 'x'
            [IO.Compression.ZipFile]::ExtractToDirectory($file, $x)
            $exe = Get-ChildItem -LiteralPath $x -Recurse -Filter 'mVolt*.exe' | Select-Object -First 1
            if (-not $exe) { throw 'mVolt+ .exe not found in the zip' }
            $file = $exe.FullName
        }
        $sig = Get-AuthenticodeSignature -LiteralPath $file
        if ($sig.Status -eq 'Valid') { Log ((T 'mVolt+: {0}') -f ('signed by ' + $sig.SignerCertificate.Subject)) }
        $target = Join-Path $dir 'mVolt+.exe'
        try { Copy-Item -LiteralPath $file -Destination $target -Force }
        catch {
            # the running mVolt+ keeps the file locked: install on the next start
            Copy-Item -LiteralPath $file -Destination (Join-Path $dir 'mVolt+.exe.new') -Force
            [IO.File]::WriteAllText((Join-Path $dir 'version.new'), $rel.Tag)
            Log (T 'mVolt+ update will be installed next start (file in use)')
            return $null
        }
        [IO.File]::WriteAllText((Join-Path $dir 'version.txt'), $rel.Tag)
        return $target
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
function Update-MVolt([bool]$force) {
    # finish an update that was waiting for the old file to be released
    foreach ($d in (Join-Path $SelfDir 'mVolt+'), (Join-Path $DataDir 'mVolt+')) {
        $n = Join-Path $d 'mVolt+.exe.new'
        if (Test-Path -LiteralPath $n) {
            try {
                Move-Item -LiteralPath $n -Destination (Join-Path $d 'mVolt+.exe') -Force
                $vn = Join-Path $d 'version.new'
                if (Test-Path -LiteralPath $vn) { Move-Item -LiteralPath $vn -Destination (Join-Path $d 'version.txt') -Force }
            } catch { }
        }
    }
    $local = Get-LocalMVolt
    if (-not $force -and $local -and $script:Cfg.mvoltChecked) {
        try { if (((Get-Date) - [DateTime]::Parse([string]$script:Cfg.mvoltChecked, [Globalization.CultureInfo]::InvariantCulture)).TotalHours -lt 12) { return } } catch { }
    }
    try {
        $rel = Get-MVoltRelease
        $script:Cfg.mvoltChecked = (Get-Date).ToString('s', [Globalization.CultureInfo]::InvariantCulture)
        $script:Dirty = $true
        $cur = $(if ($local) { Get-LocalMVoltVersion $local } else { '' })
        if ($local -and $cur -and ($cur.TrimStart('v') -eq $rel.Tag.TrimStart('v'))) {
            Log ((T 'mVolt+ is up to date ({0})') -f $rel.Tag)
            return
        }
        Show-Splash (T 'Checking mVolt+ updates…')
        $new = Install-MVolt $rel
        if ($new) {
            if ($local) { Log ((T 'mVolt+ updated: {0} → {1}') -f $(if ($cur) { $cur } else { '?' }), $rel.Tag) }
            else { Log ((T 'mVolt+ downloaded: {0}') -f "$new ($($rel.Tag))") }
        }
    } catch {
        Log ((T 'mVolt+ update check failed: {0}') -f $_.Exception.Message)
    } finally { Close-Splash }
}
function Invoke-MVolt([string[]]$a, [int]$timeout = 30000) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo($script:MVolt)
    $psi.Arguments = ($a | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.WorkingDirectory = Split-Path -Parent $script:MVolt
    $proc = [System.Diagnostics.Process]::Start($psi)
    $o = $proc.StandardOutput.ReadToEndAsync(); $e = $proc.StandardError.ReadToEndAsync()
    if (-not $proc.WaitForExit($timeout)) {
        try { $proc.Kill() } catch { }
        return @{ Code = -1; Out = (T 'mVolt+ did not respond in time'); Raw = '' }
    }
    $raw = $o.Result
    $txt = (($raw + ' ' + $e.Result) -replace '\s+', ' ').Trim()
    if ($txt.Length -gt 300) { $txt = $txt.Substring(0, 300) + '…' }
    return @{ Code = $proc.ExitCode; Out = $txt; Raw = $raw }
}
function Get-MVoltStatus {
    try {
        $r = Invoke-MVolt @('--status') 20000
        $i = $r.Raw.IndexOf('{')
        if ($i -lt 0) { return $null }
        return ($r.Raw.Substring($i) | ConvertFrom-Json)
    } catch { return $null }
}
if ($IsAdmin) { Update-MVolt $false }
$script:MVolt = Find-MVolt
$script:AppliedVolt = [int]$script:Cfg.lastVolt
$script:MVoltPowerW = [double]::NaN

# ---------------------------------------------------------------- UI
$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ClevoTune" Width="1080" Height="960" MinWidth="940" MinHeight="640"
        WindowStartupLocation="CenterScreen" Background="#0E1012" Foreground="#E6E8EA"
        FontFamily="Segoe UI" FontSize="13" WindowStyle="None" ResizeMode="CanResize"
        UseLayoutRounding="True" SnapsToDevicePixels="True">
  <WindowChrome.WindowChrome>
    <WindowChrome CaptionHeight="46" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="0" UseAeroCaptionButtons="False"/>
  </WindowChrome.WindowChrome>
  <Window.Resources>
    <SolidColorBrush x:Key="Card" Color="#15181B"/>
    <SolidColorBrush x:Key="Line" Color="#272B30"/>
    <SolidColorBrush x:Key="Muted" Color="#8B9198"/>
    <SolidColorBrush x:Key="Accent" Color="#45D3B4"/>
    <SolidColorBrush x:Key="Track" Color="#2A2F34"/>

    <Style TargetType="TextBlock"><Setter Property="Foreground" Value="#E6E8EA"/></Style>

    <Style x:Key="Btn" TargetType="Button">
      <Setter Property="Foreground" Value="#E6E8EA"/>
      <Setter Property="Background" Value="#1B1F23"/>
      <Setter Property="BorderBrush" Value="#30353B"/>
      <Setter Property="Padding" Value="16,7"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="5" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.85"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="BtnPrimary" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="#45D3B4"/>
      <Setter Property="BorderBrush" Value="#45D3B4"/>
      <Setter Property="Foreground" Value="#0B1512"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="BtnDanger" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Foreground" Value="#F07A7A"/>
      <Setter Property="BorderBrush" Value="#7A3434"/>
    </Style>
    <Style x:Key="BtnLink" TargetType="Button" BasedOn="{StaticResource Btn}">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderBrush" Value="Transparent"/>
      <Setter Property="Foreground" Value="#A9AFB5"/>
      <Setter Property="Padding" Value="10,6"/>
    </Style>
    <Style x:Key="CapBtn" TargetType="Button" BasedOn="{StaticResource BtnLink}">
      <Setter Property="WindowChrome.IsHitTestVisibleInChrome" Value="True"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Width" Value="42"/>
      <Setter Property="Padding" Value="0"/>
    </Style>

    <Style TargetType="Slider">
      <Setter Property="IsSnapToTickEnabled" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Slider">
            <Grid Height="22">
              <Border Height="4" CornerRadius="2" Background="#2A2F34" VerticalAlignment="Center"/>
              <Track x:Name="PART_Track" VerticalAlignment="Center">
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="Slider.DecreaseLarge" Focusable="False">
                    <RepeatButton.Template>
                      <ControlTemplate TargetType="RepeatButton"><Border Height="4" CornerRadius="2" Background="#45D3B4"/></ControlTemplate>
                    </RepeatButton.Template>
                  </RepeatButton>
                </Track.DecreaseRepeatButton>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="Slider.IncreaseLarge" Focusable="False">
                    <RepeatButton.Template>
                      <ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate>
                    </RepeatButton.Template>
                  </RepeatButton>
                </Track.IncreaseRepeatButton>
                <Track.Thumb>
                  <Thumb>
                    <Thumb.Template>
                      <ControlTemplate TargetType="Thumb"><Ellipse Width="16" Height="16" Fill="#45D3B4" Stroke="#E6FFF8" StrokeThickness="3"/></ControlTemplate>
                    </Thumb.Template>
                  </Thumb>
                </Track.Thumb>
              </Track>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.35"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="#E6E8EA"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <StackPanel Orientation="Horizontal" Background="Transparent">
              <Border x:Name="sw" Width="40" Height="22" CornerRadius="11" Background="#2A2F34" VerticalAlignment="Center">
                <Ellipse x:Name="knob" Width="16" Height="16" Fill="#9AA0A6" HorizontalAlignment="Left" Margin="3,0,0,0"/>
              </Border>
              <ContentPresenter Margin="10,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="sw" Property="Background" Value="#45D3B4"/>
                <Setter TargetName="knob" Property="Fill" Value="#0B1512"/>
                <Setter TargetName="knob" Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="knob" Property="Margin" Value="0,0,3,0"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#101315"/>
      <Setter Property="Foreground" Value="#E6E8EA"/>
      <Setter Property="BorderBrush" Value="#30353B"/>
      <Setter Property="CaretBrush" Value="#E6E8EA"/>
      <Setter Property="Padding" Value="6,4"/>
    </Style>

    <Style TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="#E6E8EA"/>
      <Setter Property="Background" Value="#1B1F23"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="bd" Background="{TemplateBinding Background}" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="bd" Property="Background" Value="#26413A"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="ComboBox">
      <Setter Property="Foreground" Value="#E6E8EA"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton Focusable="False" ClickMode="Press" IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border Background="#101315" BorderBrush="#30353B" BorderThickness="1" CornerRadius="5">
                      <Path HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,12,0" Data="M0,0 L5,5 L10,0" Stroke="#A9AFB5" StrokeThickness="1.6"/>
                    </Border>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <ContentPresenter IsHitTestVisible="False" Margin="12,0,30,0" VerticalAlignment="Center"
                                Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"/>
              <Popup x:Name="PART_Popup" IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
                <Border Background="#1B1F23" BorderBrush="#30353B" BorderThickness="1" CornerRadius="5" MinWidth="{TemplateBinding ActualWidth}" MaxHeight="320">
                  <ScrollViewer><ItemsPresenter/></ScrollViewer>
                </Border>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="TabItem">
      <Setter Property="Foreground" Value="#8B9198"/>
      <Setter Property="FontSize" Value="15"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabItem">
            <Grid Margin="0,0,30,0">
              <ContentPresenter ContentSource="Header" Margin="0,4,0,10"/>
              <Border x:Name="ul" Height="2" VerticalAlignment="Bottom" Background="#45D3B4" Visibility="Hidden"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="ul" Property="Visibility" Value="Visible"/>
                <Setter Property="Foreground" Value="#E6E8EA"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TabControl">
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TabControl">
            <DockPanel>
              <Border DockPanel.Dock="Top" BorderBrush="#272B30" BorderThickness="0,0,0,1" Margin="0,0,0,16">
                <TabPanel IsItemsHost="True"/>
              </Border>
              <ContentPresenter ContentSource="SelectedContent"/>
            </DockPanel>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Panel" TargetType="Border">
      <Setter Property="Background" Value="#15181B"/>
      <Setter Property="BorderBrush" Value="#272B30"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="8"/>
      <Setter Property="Padding" Value="22,18"/>
    </Style>
    <Style x:Key="Chip" TargetType="Border">
      <Setter Property="Background" Value="#15181B"/>
      <Setter Property="BorderBrush" Value="#30353B"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="15"/>
      <Setter Property="Padding" Value="12,5"/>
      <Setter Property="Margin" Value="8,0,0,0"/>
    </Style>
    <Style x:Key="Caption" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#A9AFB5"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="Small" TargetType="TextBlock">
      <Setter Property="Foreground" Value="#8B9198"/>
      <Setter Property="FontSize" Value="12"/>
    </Style>

    <Style TargetType="DataGrid">
      <Setter Property="Background" Value="#101315"/>
      <Setter Property="Foreground" Value="#E6E8EA"/>
      <Setter Property="BorderBrush" Value="#30353B"/>
      <Setter Property="RowBackground" Value="#101315"/>
      <Setter Property="AlternatingRowBackground" Value="#14171A"/>
      <Setter Property="GridLinesVisibility" Value="Horizontal"/>
      <Setter Property="HorizontalGridLinesBrush" Value="#22262A"/>
      <Setter Property="HeadersVisibility" Value="Column"/>
      <Setter Property="AutoGenerateColumns" Value="False"/>
      <Setter Property="CanUserAddRows" Value="False"/>
      <Setter Property="CanUserDeleteRows" Value="False"/>
      <Setter Property="CanUserReorderColumns" Value="False"/>
      <Setter Property="CanUserResizeRows" Value="False"/>
      <Setter Property="CanUserSortColumns" Value="False"/>
      <Setter Property="SelectionMode" Value="Single"/>
      <Setter Property="RowHeight" Value="30"/>
    </Style>
    <Style TargetType="DataGridColumnHeader">
      <Setter Property="Background" Value="#1B1F23"/>
      <Setter Property="Foreground" Value="#A9AFB5"/>
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="BorderBrush" Value="#30353B"/>
      <Setter Property="BorderThickness" Value="0,0,1,1"/>
    </Style>
    <Style TargetType="DataGridCell">
      <Setter Property="Padding" Value="10,0"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#26413A"/>
          <Setter Property="Foreground" Value="#E6E8EA"/>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>

  <Border BorderBrush="#272B30" BorderThickness="1">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="46"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- title bar -->
      <Grid Grid.Row="0" Background="#0E1012">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
          <Border Width="26" Height="26" CornerRadius="6" Background="#1C2B27">
            <Canvas Width="16" Height="16">
              <Ellipse Canvas.Left="4" Canvas.Top="4" Width="8" Height="8" Stroke="#45D3B4" StrokeThickness="2"/>
              <Line X1="0" Y1="8" X2="4" Y2="8" Stroke="#45D3B4" StrokeThickness="2"/>
              <Line X1="12" Y1="8" X2="16" Y2="8" Stroke="#45D3B4" StrokeThickness="2"/>
              <Line X1="8" Y1="12" X2="8" Y2="16" Stroke="#45D3B4" StrokeThickness="2"/>
            </Canvas>
          </Border>
          <TextBlock Text="ClevoTune" FontSize="15" FontWeight="SemiBold" Margin="10,0,0,0" VerticalAlignment="Center"/>
          <TextBlock x:Name="TxtVersion" Text="v1.6.3" Foreground="#6C727A" Margin="8,0,0,0" VerticalAlignment="Center"/>
          <TextBlock x:Name="TxtModel" Text="" Foreground="#6C727A" Margin="14,0,0,0" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="BtnMin" Style="{StaticResource CapBtn}" Content="—"/>
          <Button x:Name="BtnMax" Style="{StaticResource CapBtn}" Content="☐"/>
          <Button x:Name="BtnClose" Style="{StaticResource CapBtn}" Content="✕"/>
        </StackPanel>
      </Grid>

      <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="30,6,30,16">
        <StackPanel>
          <!-- header -->
          <Grid Margin="0,4,0,18">
            <StackPanel>
              <TextBlock x:Name="TxtGpuName" Text="NVIDIA GeForce RTX 3080 Laptop GPU" FontSize="22" FontWeight="SemiBold"/>
              <TextBlock x:Name="TxtGpuSub" Text="" Foreground="#8B9198" Margin="0,4,0,0"/>
            </StackPanel>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
              <Border Style="{StaticResource Chip}"><StackPanel Orientation="Horizontal"><Ellipse x:Name="DotPawn" Width="7" Height="7" Fill="#45D3B4" Margin="0,0,8,0"/><TextBlock x:Name="ChipPawn" Text="PawnIO"/></StackPanel></Border>
              <Border Style="{StaticResource Chip}"><StackPanel Orientation="Horizontal"><Ellipse x:Name="DotNv" Width="7" Height="7" Fill="#45D3B4" Margin="0,0,8,0"/><TextBlock x:Name="ChipNv" Text="NVAPI"/></StackPanel></Border>
              <Border Style="{StaticResource Chip}"><StackPanel Orientation="Horizontal"><Ellipse x:Name="DotAdmin" Width="7" Height="7" Fill="#45D3B4" Margin="0,0,8,0"/><TextBlock x:Name="ChipAdmin" Text="Administrator"/></StackPanel></Border>
              <Border Style="{StaticResource Chip}"><StackPanel Orientation="Horizontal"><Ellipse x:Name="DotAuto" Width="7" Height="7" Fill="#45D3B4" Margin="0,0,8,0"/><TextBlock x:Name="ChipAuto" Text="Auto-apply: —"/></StackPanel></Border>
            </StackPanel>
          </Grid>

          <!-- sensor cards (filled in code) -->
          <UniformGrid x:Name="CardsGrid" Columns="6" Rows="2" Margin="-6,0,-6,22"/>

          <TabControl x:Name="Tabs">
            <!-- ============================== GPU tuning -->
            <TabItem Header="GPU tuning">
              <StackPanel>
                <Border Style="{StaticResource Panel}">
                  <StackPanel>
                    <Grid Margin="0,0,0,14">
                      <TextBlock Text="TUNING" Style="{StaticResource Caption}" VerticalAlignment="Center"/>
                      <Border HorizontalAlignment="Right" Background="#16302A" CornerRadius="12" Padding="12,4">
                        <StackPanel Orientation="Horizontal"><Ellipse x:Name="DotLive" Width="7" Height="7" Fill="#45D3B4" Margin="0,0,8,0"/><TextBlock x:Name="TxtLive" Text="Card values" Foreground="#45D3B4"/></StackPanel>
                      </Border>
                    </Grid>

                    <!-- power limit -->
                    <Grid Margin="0,0,0,18">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="220"/><ColumnDefinition Width="*"/><ColumnDefinition Width="190"/></Grid.ColumnDefinitions>
                      <StackPanel>
                        <TextBlock Text="Power limit (TGP)" FontSize="15"/>
                        <TextBlock x:Name="CardPower" Text="on card: —" Style="{StaticResource Small}" Margin="0,4,0,0"/>
                      </StackPanel>
                      <StackPanel Grid.Column="1" Margin="10,2,24,0">
                        <Slider x:Name="SlPower" Minimum="60" Maximum="160" Value="115" TickFrequency="1" SmallChange="1" LargeChange="5"/>
                        <Grid><TextBlock x:Name="LblPowerMin" Text="60 W" Style="{StaticResource Small}"/><TextBlock x:Name="LblPowerMax" Text="160 W" Style="{StaticResource Small}" HorizontalAlignment="Right"/></Grid>
                      </StackPanel>
                      <StackPanel Grid.Column="2" HorizontalAlignment="Right">
                        <TextBlock x:Name="ValPower" Text="—" FontSize="22" HorizontalAlignment="Right"/>
                        <TextBlock x:Name="DeltaPower" Text="" Style="{StaticResource Small}" HorizontalAlignment="Right"/>
                      </StackPanel>
                    </Grid>

                    <!-- core offset -->
                    <Grid Margin="0,0,0,18">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="220"/><ColumnDefinition Width="*"/><ColumnDefinition Width="190"/></Grid.ColumnDefinitions>
                      <StackPanel>
                        <TextBlock Text="Core clock offset" FontSize="15"/>
                        <TextBlock x:Name="CardCore" Text="on card: —" Style="{StaticResource Small}" Margin="0,4,0,0"/>
                      </StackPanel>
                      <StackPanel Grid.Column="1" Margin="10,2,24,0">
                        <Slider x:Name="SlCore" Minimum="-300" Maximum="300" Value="0" TickFrequency="5" SmallChange="5" LargeChange="25"/>
                        <Grid><TextBlock x:Name="LblCoreMin" Text="-300 MHz" Style="{StaticResource Small}"/><TextBlock x:Name="LblCoreMax" Text="+300 MHz" Style="{StaticResource Small}" HorizontalAlignment="Right"/></Grid>
                      </StackPanel>
                      <StackPanel Grid.Column="2" HorizontalAlignment="Right">
                        <TextBlock x:Name="ValCore" Text="+0 MHz" FontSize="22" HorizontalAlignment="Right"/>
                        <TextBlock x:Name="DeltaCore" Text="" Style="{StaticResource Small}" HorizontalAlignment="Right"/>
                      </StackPanel>
                    </Grid>

                    <!-- memory offset -->
                    <Grid Margin="0,0,0,18">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="220"/><ColumnDefinition Width="*"/><ColumnDefinition Width="190"/></Grid.ColumnDefinitions>
                      <StackPanel>
                        <TextBlock Text="Memory clock offset" FontSize="15"/>
                        <TextBlock x:Name="CardMem" Text="on card: —" Style="{StaticResource Small}" Margin="0,4,0,0"/>
                      </StackPanel>
                      <StackPanel Grid.Column="1" Margin="10,2,24,0">
                        <Slider x:Name="SlMem" Minimum="-500" Maximum="1500" Value="0" TickFrequency="10" SmallChange="10" LargeChange="50"/>
                        <Grid><TextBlock x:Name="LblMemMin" Text="-500 MHz" Style="{StaticResource Small}"/><TextBlock x:Name="LblMemMax" Text="+1500 MHz" Style="{StaticResource Small}" HorizontalAlignment="Right"/></Grid>
                      </StackPanel>
                      <StackPanel Grid.Column="2" HorizontalAlignment="Right">
                        <TextBlock x:Name="ValMem" Text="+0 MHz" FontSize="22" HorizontalAlignment="Right"/>
                        <TextBlock x:Name="DeltaMem" Text="" Style="{StaticResource Small}" HorizontalAlignment="Right"/>
                      </StackPanel>
                    </Grid>

                    <!-- clock limit (undervolt helper) -->
                    <Grid Margin="0,0,0,8">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="220"/><ColumnDefinition Width="*"/><ColumnDefinition Width="190"/></Grid.ColumnDefinitions>
                      <StackPanel>
                        <CheckBox x:Name="ChkLock" Content="Max clock limit"/>
                        <TextBlock x:Name="CardLock" Text="applied: off" Style="{StaticResource Small}" Margin="50,4,0,0"/>
                      </StackPanel>
                      <StackPanel Grid.Column="1" Margin="10,2,24,0">
                        <Slider x:Name="SlLock" Minimum="900" Maximum="2400" Value="1800" TickFrequency="15" SmallChange="15" LargeChange="75"/>
                        <Grid><TextBlock Text="900 MHz" Style="{StaticResource Small}"/><TextBlock Text="2400 MHz" Style="{StaticResource Small}" HorizontalAlignment="Right"/></Grid>
                      </StackPanel>
                      <StackPanel Grid.Column="2" HorizontalAlignment="Right">
                        <TextBlock x:Name="ValLock" Text="off" FontSize="22" HorizontalAlignment="Right"/>
                        <TextBlock Text="limits voltage via the V/F curve" Style="{StaticResource Small}" HorizontalAlignment="Right"/>
                      </StackPanel>
                    </Grid>

                    <!-- core voltage offset (mVolt+) -->
                    <Grid Margin="0,10,0,8">
                      <Grid.ColumnDefinitions><ColumnDefinition Width="220"/><ColumnDefinition Width="*"/><ColumnDefinition Width="190"/></Grid.ColumnDefinitions>
                      <StackPanel>
                        <TextBlock Text="Core voltage offset (mVolt+)" FontSize="15"/>
                        <TextBlock x:Name="CardVolt" Text="requires mVolt+" Style="{StaticResource Small}" Margin="0,4,0,0"/>
                      </StackPanel>
                      <StackPanel Grid.Column="1" Margin="10,2,24,0">
                        <Slider x:Name="SlVolt" Minimum="-250" Maximum="100" Value="0" TickFrequency="5" SmallChange="5" LargeChange="25"/>
                        <Grid><TextBlock Text="-250 mV" Style="{StaticResource Small}"/><TextBlock Text="+100 mV" Style="{StaticResource Small}" HorizontalAlignment="Right"/></Grid>
                      </StackPanel>
                      <StackPanel Grid.Column="2" HorizontalAlignment="Right">
                        <TextBlock x:Name="ValVolt" Text="+0 mV" FontSize="22" HorizontalAlignment="Right"/>
                        <TextBlock x:Name="DeltaVolt" Text="" Style="{StaticResource Small}" HorizontalAlignment="Right"/>
                      </StackPanel>
                    </Grid>

                    <TextBlock TextWrapping="Wrap" Style="{StaticResource Small}" Margin="0,6,0,0"
                               Text="Undervolting on Ampere: a clock limit plus a positive core offset (e.g. 1800 MHz + 150) makes the GPU reach that clock at a lower voltage. Direct voltage control is still done in mVolt+."/>

                    <Border Height="1" Background="#272B30" Margin="0,18,0,18"/>
                    <Grid>
                      <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                        <Button x:Name="BtnApply" Style="{StaticResource BtnPrimary}" Content="Apply to GPU" Width="200" Height="44" FontSize="15"/>
                        <Button x:Name="BtnStock" Style="{StaticResource Btn}" Content="Reset to stock" Height="44" Margin="12,0,0,0" FontSize="14"/>
                      </StackPanel>
                      <Button x:Name="BtnRefresh" Style="{StaticResource BtnLink}" Content="Refresh readback" HorizontalAlignment="Right" FontSize="14"/>
                    </Grid>
                  </StackPanel>
                </Border>

                <Border Style="{StaticResource Panel}" Margin="0,18,0,0">
                  <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="340"/></Grid.ColumnDefinitions>
                    <StackPanel>
                      <TextBlock Text="PROFILES" Style="{StaticResource Caption}" Margin="0,0,0,12"/>
                      <StackPanel Orientation="Horizontal">
                        <ComboBox x:Name="CmbProfiles" Width="260"/>
                        <Button x:Name="BtnLoad" Style="{StaticResource Btn}" Content="Load" Margin="12,0,0,0"/>
                        <Button x:Name="BtnSaveAs" Style="{StaticResource Btn}" Content="Save as…" Margin="10,0,0,0"/>
                        <Button x:Name="BtnDelete" Style="{StaticResource BtnDanger}" Content="Delete" Margin="10,0,0,0"/>
                      </StackPanel>
                      <TextBlock x:Name="TxtProfileInfo" Text="" Style="{StaticResource Small}" Margin="2,10,0,0"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" VerticalAlignment="Center">
                      <CheckBox x:Name="ChkApplyOnOpen" Content="Apply the last profile on open" FontSize="14"/>
                      <TextBlock Text="Applies the most recently saved profile every time the app opens" Style="{StaticResource Small}" TextWrapping="Wrap" Margin="50,6,0,14"/>
                      <CheckBox x:Name="ChkAutoApply" Content="Start with Windows (at sign-in)" FontSize="14"/>
                      <TextBlock x:Name="TxtAutoInfo" Text="Starts in the tray, applies the last profile and controls the fans" Style="{StaticResource Small}" TextWrapping="Wrap" Margin="50,6,0,0"/>
                    </StackPanel>
                  </Grid>
                </Border>
              </StackPanel>
            </TabItem>

            <!-- ============================== Fans -->
            <TabItem Header="Fans">
              <StackPanel>
                <Border Style="{StaticResource Panel}">
                  <Grid>
                    <Grid.ColumnDefinitions><ColumnDefinition Width="210"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                    <StackPanel>
                      <TextBlock Text="FANS (EC)" Style="{StaticResource Caption}" Margin="0,0,0,12"/>
                      <StackPanel x:Name="FanList"/>
                      <TextBlock x:Name="TxtFanNote" Text="" Style="{StaticResource Small}" TextWrapping="Wrap" Margin="0,10,10,0"/>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Margin="18,0,0,0">
                      <StackPanel Margin="0,0,0,14">
                        <WrapPanel Orientation="Horizontal">
                          <StackPanel>
                            <TextBlock Text="Mode" Style="{StaticResource Small}" Margin="0,0,0,4"/>
                            <ComboBox x:Name="CmbFanMode" Width="170">
                              <ComboBoxItem Content="Automatic (EC)"/>
                              <ComboBoxItem Content="Curve"/>
                              <ComboBoxItem Content="Fixed"/>
                            </ComboBox>
                          </StackPanel>
                          <StackPanel Margin="14,0,0,0">
                            <TextBlock Text="Sensor" Style="{StaticResource Small}" Margin="0,0,0,4"/>
                            <ComboBox x:Name="CmbFanSource" Width="190">
                              <ComboBoxItem Content="CPU temp"/>
                              <ComboBoxItem Content="GPU temp"/>
                              <ComboBoxItem Content="Max CPU/GPU temp"/>
                              <ComboBoxItem Content="CPU load"/>
                              <ComboBoxItem Content="GPU load"/>
                              <ComboBoxItem Content="Max CPU/GPU load"/>
                            </ComboBox>
                          </StackPanel>
                          <StackPanel Margin="14,0,0,0">
                            <TextBlock Text="Preset" Style="{StaticResource Small}" Margin="0,0,0,4"/>
                            <ComboBox x:Name="CmbPreset" Width="170">
                              <ComboBoxItem Content="Quiet"/>
                              <ComboBoxItem Content="Balanced"/>
                              <ComboBoxItem Content="Cool"/>
                              <ComboBoxItem Content="Maximum"/>
                            </ComboBox>
                          </StackPanel>
                        </WrapPanel>
                        <TextBlock x:Name="TxtFanLive" Text="" Margin="0,10,0,0" Foreground="#45D3B4" FontSize="14" TextTrimming="CharacterEllipsis"/>
                      </StackPanel>

                      <StackPanel x:Name="PnlFixed" Visibility="Collapsed" Margin="0,0,0,14">
                        <Grid>
                          <TextBlock Text="Fixed speed" FontSize="14"/>
                          <TextBlock x:Name="ValFixed" Text="60 %" FontSize="18" HorizontalAlignment="Right"/>
                        </Grid>
                        <Slider x:Name="SlFixed" Minimum="0" Maximum="100" Value="60" TickFrequency="1" SmallChange="1" LargeChange="5" Margin="0,6,0,0"/>
                      </StackPanel>

                      <Grid x:Name="PnlCurve">
                        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="230"/></Grid.ColumnDefinitions>
                        <Border Background="#101315" BorderBrush="#272B30" BorderThickness="1" CornerRadius="6" Height="300">
                          <Canvas x:Name="CurveCanvas" ClipToBounds="True" Background="Transparent" Cursor="Cross"/>
                        </Border>
                        <StackPanel Grid.Column="1" Margin="14,0,0,0">
                          <DataGrid x:Name="GridPoints" Height="236">
                            <DataGrid.Columns>
                              <DataGridTextColumn Header="Temp. (°C)" Binding="{Binding Temp, UpdateSourceTrigger=LostFocus}" Width="*"/>
                              <DataGridTextColumn Header="Fan (%)" Binding="{Binding Pct, UpdateSourceTrigger=LostFocus}" Width="*"/>
                            </DataGrid.Columns>
                          </DataGrid>
                          <StackPanel Orientation="Horizontal" Margin="0,10,0,0">
                            <Button x:Name="BtnAddPt" Style="{StaticResource Btn}" Content="+ Point" Padding="12,6"/>
                            <Button x:Name="BtnDelPt" Style="{StaticResource BtnDanger}" Content="Remove" Padding="12,6" Margin="8,0,0,0"/>
                          </StackPanel>
                        </StackPanel>
                      </Grid>
                      <Grid Margin="0,14,0,0">
                        <CheckBox x:Name="ChkCfcGrid" Content="Fixed 40–85 °C grid (like ClevoFanControl)" VerticalAlignment="Center"/>
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                          <Button x:Name="BtnImportCfc" Style="{StaticResource Btn}" Content="Import .cfg" Padding="12,6"/>
                          <Button x:Name="BtnExportCfc" Style="{StaticResource Btn}" Content="Export .cfg" Padding="12,6" Margin="8,0,0,0"/>
                          <Button x:Name="BtnSaveCurves" Style="{StaticResource BtnPrimary}" Content="Save curves" Padding="14,6" Margin="8,0,0,0"/>
                        </StackPanel>
                      </Grid>
                      <TextBlock x:Name="TxtCurveHelp" Text="" Style="{StaticResource Small}" TextWrapping="Wrap" Margin="0,10,0,0"/>
                    </StackPanel>
                  </Grid>
                </Border>

                <Border Style="{StaticResource Panel}" Margin="0,18,0,0">
                  <StackPanel>
                    <TextBlock Text="BEHAVIOUR" Style="{StaticResource Caption}" Margin="0,0,0,14"/>
                    <Grid>
                      <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
                      <StackPanel Margin="0,0,24,0">
                        <Grid><TextBlock Text="Hysteresis"/><TextBlock x:Name="ValHyst" Text="3" HorizontalAlignment="Right"/></Grid>
                        <Slider x:Name="SlHyst" Minimum="0" Maximum="10" Value="3" TickFrequency="1" Margin="0,6,0,0"/>
                        <TextBlock Text="only slows down after dropping X (°C or % load)" Style="{StaticResource Small}" TextWrapping="Wrap"/>
                      </StackPanel>
                      <StackPanel Grid.Column="1" Margin="0,0,24,0">
                        <Grid><TextBlock Text="Max ramp-down"/><TextBlock x:Name="ValDown" Text="3 %/s" HorizontalAlignment="Right"/></Grid>
                        <Slider x:Name="SlDown" Minimum="1" Maximum="20" Value="3" TickFrequency="1" Margin="0,6,0,0"/>
                        <TextBlock Text="smooths slowing down (speeding up is instant)" Style="{StaticResource Small}"/>
                      </StackPanel>
                      <StackPanel Grid.Column="2" Margin="0,0,24,0">
                        <Grid><TextBlock Text="Load smoothing"/><TextBlock x:Name="ValLoadSm" Text="3 s" HorizontalAlignment="Right"/></Grid>
                        <Slider x:Name="SlLoadSm" Minimum="0" Maximum="15" Value="3" TickFrequency="1" Margin="0,6,0,0"/>
                        <TextBlock Text="averages the load to ignore spikes (load curves)" Style="{StaticResource Small}" TextWrapping="Wrap"/>
                      </StackPanel>
                      <StackPanel Grid.Column="3">
                        <Grid><TextBlock Text="Safety temperature"/><TextBlock x:Name="ValFail" Text="92 °C" HorizontalAlignment="Right"/></Grid>
                        <Slider x:Name="SlFail" Minimum="75" Maximum="100" Value="92" TickFrequency="1" Margin="0,6,0,0"/>
                        <TextBlock Text="CPU or GPU above this → 100% (load curves too)" Style="{StaticResource Small}" TextWrapping="Wrap"/>
                      </StackPanel>
                    </Grid>
                    <StackPanel Orientation="Horizontal" Margin="0,16,0,0">
                      <Button x:Name="BtnAllAuto" Style="{StaticResource Btn}" Content="Return all to EC (auto)"/>
                    </StackPanel>
                  </StackPanel>
                </Border>
              </StackPanel>
            </TabItem>

            <!-- ============================== Overlay -->
            <TabItem Header="Overlay">
              <Border Style="{StaticResource Panel}">
                <StackPanel>
                  <TextBlock Text="ON-SCREEN OVERLAY" Style="{StaticResource Caption}" Margin="0,0,0,14"/>
                  <CheckBox x:Name="ChkOverlay" Content="Show overlay (over windowed/borderless games)" FontSize="14"/>
                  <Grid Margin="0,18,0,0">
                    <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
                    <StackPanel Margin="0,0,24,0">
                      <TextBlock Text="Position" Style="{StaticResource Small}" Margin="0,0,0,4"/>
                      <ComboBox x:Name="CmbOvlPos">
                        <ComboBoxItem Content="Top left"/>
                        <ComboBoxItem Content="Top right"/>
                        <ComboBoxItem Content="Bottom left"/>
                        <ComboBoxItem Content="Bottom right"/>
                      </ComboBox>
                    </StackPanel>
                    <StackPanel Grid.Column="1" Margin="0,0,24,0">
                      <Grid><TextBlock Text="Font size"/><TextBlock x:Name="ValOvlFont" Text="14" HorizontalAlignment="Right"/></Grid>
                      <Slider x:Name="SlOvlFont" Minimum="10" Maximum="28" Value="14" TickFrequency="1" Margin="0,6,0,0"/>
                    </StackPanel>
                    <StackPanel Grid.Column="2">
                      <Grid><TextBlock Text="Background opacity"/><TextBlock x:Name="ValOvlOp" Text="55 %" HorizontalAlignment="Right"/></Grid>
                      <Slider x:Name="SlOvlOp" Minimum="0" Maximum="100" Value="55" TickFrequency="5" Margin="0,6,0,0"/>
                    </StackPanel>
                  </Grid>
                  <TextBlock Text="Show" Style="{StaticResource Small}" Margin="0,18,0,8"/>
                  <WrapPanel>
                    <CheckBox x:Name="OvlCpu" Content="CPU (temp/load/W)" Margin="0,0,24,8" IsChecked="True"/>
                    <CheckBox x:Name="OvlGpu" Content="GPU (temp/load/W)" Margin="0,0,24,8" IsChecked="True"/>
                    <CheckBox x:Name="OvlClk" Content="GPU clocks" Margin="0,0,24,8" IsChecked="True"/>
                    <CheckBox x:Name="OvlFan" Content="Fans" Margin="0,0,24,8" IsChecked="True"/>
                    <CheckBox x:Name="OvlMem" Content="RAM/VRAM" Margin="0,0,24,8"/>
                  </WrapPanel>
                  <TextBlock Text="Not shown over exclusive fullscreen games — use borderless mode. Does not show FPS." Style="{StaticResource Small}" TextWrapping="Wrap" Margin="0,8,0,0"/>
                </StackPanel>
              </Border>
            </TabItem>

            <!-- ============================== Settings -->
            <TabItem Header="Settings">
              <StackPanel>
                <Border Style="{StaticResource Panel}">
                  <StackPanel>
                    <TextBlock Text="HARDWARE ACCESS (PawnIO)" Style="{StaticResource Caption}" Margin="0,0,0,12"/>
                    <TextBlock x:Name="TxtPawnStatus" Text="" TextWrapping="Wrap" Margin="0,0,0,12"/>
                    <WrapPanel>
                      <Button x:Name="BtnPawnSite" Style="{StaticResource Btn}" Content="PawnIO website" Margin="0,0,10,8"/>
                      <Button x:Name="BtnModules" Style="{StaticResource BtnPrimary}" Content="Reinstall driver + modules" Margin="0,0,10,8"/>
                      <Button x:Name="BtnModFolder" Style="{StaticResource Btn}" Content="Open modules folder" Margin="0,0,10,8"/>
                      <Button x:Name="BtnReinit" Style="{StaticResource Btn}" Content="Reinitialise sensors" Margin="0,0,10,8"/>
                    </WrapPanel>
                    <TextBlock Text="Everything is installed automatically on first launch: the official PawnIO driver (signature checked before installing) and the LpcACPIEC.bin (fans) and IntelMSR.bin (CPU) modules from the latest PawnIO.Modules release." Style="{StaticResource Small}" TextWrapping="Wrap" Margin="0,4,0,0"/>
                  </StackPanel>
                </Border>
                <Border Style="{StaticResource Panel}" Margin="0,18,0,0">
                  <StackPanel>
                    <TextBlock Text="MVOLT+ (OPTIONAL)" Style="{StaticResource Caption}" Margin="0,0,0,12"/>
                    <TextBlock x:Name="TxtMVolt" Text="" TextWrapping="Wrap" Margin="0,0,0,12"/>
                    <WrapPanel>
                      <Button x:Name="BtnMVoltUpdate" Style="{StaticResource BtnPrimary}" Content="Check for mVolt+ updates" Margin="0,0,10,8"/>
                      <Button x:Name="BtnMVoltSite" Style="{StaticResource Btn}" Content="mVolt+ website" Margin="0,0,10,8"/>
                    </WrapPanel>
                    <TextBlock Text="mVolt+ (by b00nz) is kept in a mVolt+ folder next to ClevoTune and updated automatically from its GitHub releases (checked at most every 12 hours). ClevoTune runs it through its command line for the power limit when the NVIDIA driver blocks it, and for the core voltage offset." Style="{StaticResource Small}" TextWrapping="Wrap" Margin="0,4,0,0"/>
                  </StackPanel>
                </Border>
                <Border Style="{StaticResource Panel}" Margin="0,18,0,0">
                  <StackPanel>
                    <TextBlock Text="APPLICATION" Style="{StaticResource Caption}" Margin="0,0,0,14"/>
                    <CheckBox x:Name="ChkStartup" Content="Start with Windows (at sign-in)" FontSize="14"/>
                    <TextBlock Text="Starts minimised in the tray when you sign in to Windows, without a UAC prompt, applies the last profile and controls the fans" Style="{StaticResource Small}" TextWrapping="Wrap" Margin="50,6,0,14"/>
                    <CheckBox x:Name="ChkCloseTray" Content="Closing the window minimises to the tray (fans stay controlled)" Margin="0,0,0,12"/>
                    <StackPanel Orientation="Horizontal">
                      <TextBlock Text="Polling interval" VerticalAlignment="Center" Margin="0,0,14,0"/>
                      <ComboBox x:Name="CmbInterval" Width="140">
                        <ComboBoxItem Content="500 ms"/>
                        <ComboBoxItem Content="1000 ms"/>
                        <ComboBoxItem Content="2000 ms"/>
                      </ComboBox>
                    </StackPanel>
                    <StackPanel Orientation="Horizontal" Margin="0,12,0,0">
                      <TextBlock Text="Language" VerticalAlignment="Center" Margin="0,0,14,0"/>
                      <ComboBox x:Name="CmbLang" Width="200"/>
                      <Button x:Name="BtnLangFolder" Style="{StaticResource Btn}" Content="Open language folder" Margin="10,0,0,0" Padding="12,6"/>
                    </StackPanel>
                    <TextBlock x:Name="TxtPaths" Text="" Style="{StaticResource Small}" TextWrapping="Wrap" Margin="0,14,0,0"/>
                  </StackPanel>
                </Border>
              </StackPanel>
            </TabItem>
          </TabControl>
        </StackPanel>
      </ScrollViewer>

      <!-- activity log -->
      <Border x:Name="LogPanel" Grid.Row="2" Visibility="Collapsed" BorderBrush="#272B30" BorderThickness="0,1,0,0" Background="#0B0D0F" Height="160">
        <TextBox x:Name="TxtLog" IsReadOnly="True" Background="Transparent" BorderThickness="0" FontFamily="Consolas" FontSize="12"
                 Foreground="#A9AFB5" VerticalScrollBarVisibility="Auto" TextWrapping="NoWrap" Padding="22,8"/>
      </Border>

      <!-- status bar -->
      <Border Grid.Row="3" BorderBrush="#272B30" BorderThickness="0,1,0,0" Background="#0E1012" Padding="26,10">
        <Grid>
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <Ellipse x:Name="DotStatus" Width="8" Height="8" Fill="#45D3B4" Margin="0,0,10,0"/>
            <TextBlock x:Name="TxtStatus" Text="Starting…"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BtnLog" Style="{StaticResource BtnLink}" Content="Log ▴"/>
          </StackPanel>
        </Grid>
      </Border>
    </Grid>
  </Border>
</Window>

'@

$app = New-Object System.Windows.Application
$app.ShutdownMode = [System.Windows.ShutdownMode]::OnExplicitShutdown
$win = [Windows.Markup.XamlReader]::Parse($Xaml)
$ui = @{}
foreach ($m in [regex]::Matches($Xaml, 'x:Name="(\w+)"')) { $n = $m.Groups[1].Value; $ui[$n] = $win.FindName($n) }
foreach ($l in $script:PendingLog) { $ui.TxtLog.AppendText($l + "`r`n") }
$script:PendingLog.Clear()

$script:LangTargets = New-Object System.Collections.ArrayList
function Collect-LangTargets($o) {
    if ($null -eq $o) { return }
    if ($o -is [System.Windows.Controls.TextBlock]) {
        if ($o.Text -and $script:LangKeys.Contains($o.Text)) { [void]$script:LangTargets.Add(@{ O = $o; P = 'Text'; K = $o.Text }) }
    }
    if ($o -is [System.Windows.Controls.HeaderedContentControl] -and $o.Header -is [string]) {
        if ($script:LangKeys.Contains($o.Header)) { [void]$script:LangTargets.Add(@{ O = $o; P = 'Header'; K = $o.Header }) }
    }
    if ($o -is [System.Windows.Controls.ContentControl] -and $o.Content -is [string]) {
        if ($script:LangKeys.Contains($o.Content)) { [void]$script:LangTargets.Add(@{ O = $o; P = 'Content'; K = $o.Content }) }
    }
    if ($o -is [System.Windows.Controls.DataGrid]) {
        foreach ($col in $o.Columns) { if ($col.Header -is [string] -and $script:LangKeys.Contains($col.Header)) { [void]$script:LangTargets.Add(@{ O = $col; P = 'Header'; K = $col.Header }) } }
    }
    if ($o -is [System.Windows.DependencyObject]) {
        foreach ($c in [System.Windows.LogicalTreeHelper]::GetChildren($o)) { if ($c -is [System.Windows.DependencyObject]) { Collect-LangTargets $c } }
    }
}
function Apply-LangTargets { foreach ($t in $script:LangTargets) { try { $t.O.($t.P) = (T $t.K) } catch { } } }
Collect-LangTargets $win
Apply-LangTargets

$BC = New-Object System.Windows.Media.BrushConverter
function Brush([string]$hex) { return $BC.ConvertFromString($hex) }
function Thick([double]$l, [double]$t, [double]$r, [double]$b) { return New-Object System.Windows.Thickness($l, $t, $r, $b) }
$Green = Brush '#45D3B4'; $Yellow = Brush '#F2C94C'; $Red = Brush '#F07A7A'; $Grey = Brush '#6C727A'

function Fmt($v, [string]$f) { if ($null -eq $v -or [double]::IsNaN([double]$v)) { return '—' }; return ([double]$v).ToString($f) }
function Signed([double]$v) { if ($v -gt 0) { return '+' + $v.ToString('0') }; return $v.ToString('0') }

function Set-Status([string]$m, $brush) {
    if (-not $brush) { $brush = $Green }
    $ui.TxtStatus.Text = $m
    $ui.DotStatus.Fill = $brush
}

# ---------------------------------------------------------------- icon
$bmp = New-Object System.Drawing.Bitmap 32, 32
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)
$g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 28, 43, 39))), 0, 0, 31, 31)
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 69, 211, 180)), 3
$g.DrawEllipse($pen, 10, 10, 12, 12); $g.DrawLine($pen, 2, 16, 10, 16); $g.DrawLine($pen, 22, 16, 30, 16); $g.DrawLine($pen, 16, 22, 16, 30)
$g.Dispose()
$AppIcon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
try {
    $win.Icon = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($AppIcon.Handle, [System.Windows.Int32Rect]::Empty, [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
} catch { }

# ---------------------------------------------------------------- sensor cards
$script:Cards = @{}
function New-Card([string]$key, [string]$title, [string]$unit, [string]$color, [double]$min, [double]$max) {
    $b = New-Object System.Windows.Controls.Border
    $b.Background = Brush '#15181B'; $b.BorderBrush = Brush '#272B30'; $b.BorderThickness = Thick 1 1 1 1
    $b.CornerRadius = New-Object System.Windows.CornerRadius 8
    $b.Margin = Thick 6 6 6 6; $b.Padding = Thick 16 14 16 12; $b.Height = 140

    $grid = New-Object System.Windows.Controls.Grid
    foreach ($h in 'Auto', 'Auto', '*') {
        $rd = New-Object System.Windows.Controls.RowDefinition
        if ($h -eq '*') { $rd.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { $rd.Height = [System.Windows.GridLength]::Auto }
        $grid.RowDefinitions.Add($rd)
    }
    $top = New-Object System.Windows.Controls.Grid
    $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $top.ColumnDefinitions.Add($c0); $top.ColumnDefinitions.Add($c1)
    $t = New-Object System.Windows.Controls.TextBlock; $t.Text = (T $title); $t.Foreground = Brush '#A9AFB5'; $t.FontSize = 12; $t.FontWeight = 'SemiBold'
    $t.TextTrimming = 'CharacterEllipsis'; $t.VerticalAlignment = 'Center'
    $extra = New-Object System.Windows.Controls.TextBlock; $extra.Foreground = Brush '#6C727A'; $extra.FontSize = 11; $extra.HorizontalAlignment = 'Right'
    $extra.VerticalAlignment = 'Center'; $extra.Margin = Thick 8 0 0 0; $extra.TextTrimming = 'CharacterEllipsis'
    [System.Windows.Controls.Grid]::SetColumn($extra, 1)
    [void]$top.Children.Add($t); [void]$top.Children.Add($extra)
    [System.Windows.Controls.Grid]::SetRow($top, 0); [void]$grid.Children.Add($top)

    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'; $sp.Margin = Thick 0 8 0 0
    $v = New-Object System.Windows.Controls.TextBlock; $v.Text = '—'; $v.FontSize = 30; $v.Foreground = Brush $color
    $u = New-Object System.Windows.Controls.TextBlock; $u.Text = $unit; $u.FontSize = 14; $u.Foreground = Brush '#8B9198'; $u.Margin = Thick 6 0 0 6; $u.VerticalAlignment = 'Bottom'
    $s = New-Object System.Windows.Controls.TextBlock; $s.Text = ''; $s.FontSize = 14; $s.Foreground = Brush '#6C727A'; $s.Margin = Thick 6 0 0 6; $s.VerticalAlignment = 'Bottom'
    [void]$sp.Children.Add($v); [void]$sp.Children.Add($u); [void]$sp.Children.Add($s)
    [System.Windows.Controls.Grid]::SetRow($sp, 1); [void]$grid.Children.Add($sp)

    $cv = New-Object System.Windows.Controls.Canvas; $cv.Margin = Thick 0 8 0 0; $cv.ClipToBounds = $true
    $fill = New-Object System.Windows.Shapes.Polygon
    $fc = (Brush $color).Color; $fill.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(40, $fc.R, $fc.G, $fc.B))
    $line = New-Object System.Windows.Shapes.Polyline; $line.Stroke = Brush $color; $line.StrokeThickness = 1.6; $line.StrokeLineJoin = 'Round'
    [void]$cv.Children.Add($fill); [void]$cv.Children.Add($line)
    [System.Windows.Controls.Grid]::SetRow($cv, 2); [void]$grid.Children.Add($cv)

    $b.Child = $grid
    [void]$ui.CardsGrid.Children.Add($b)
    $script:Cards[$key] = @{ Title = $t; TitleKey = $title; Value = $v; Unit = $u; Sub = $s; Extra = $extra; Canvas = $cv; Line = $line; Fill = $fill; Hist = (New-Object 'System.Collections.Generic.List[double]'); Min = $min; Max = $max }
}

New-Card 'cpuTemp' 'CPU TEMP'    '°C'  '#59D9A6' 20 100
New-Card 'cpuFan'  'CPU FAN'     '%'   '#B4E37A' 0 100
New-Card 'cpuClk'  'CPU CLOCK'   'MHz' '#8EC5FF' 0 5000
New-Card 'cpuLoad' 'CPU LOAD'    '%'   '#D98BD9' 0 100
New-Card 'cpuPow'  'CPU POWER'   'W'   '#F2C94C' 0 60
New-Card 'ram'     'RAM'         'GB'  '#8FA2FF' 0 32
New-Card 'gpuTemp' 'GPU TEMP'    '°C'  '#59D9A6' 20 100
New-Card 'gpuFan'  'GPU FAN'     '%'   '#B4E37A' 0 100
New-Card 'gpuClk'  'GPU CLOCK'   'MHz' '#8EC5FF' 0 2100
New-Card 'gpuLoad' 'GPU LOAD'    '%'   '#D98BD9' 0 100
New-Card 'gpuPow'  'GPU POWER'   'W'   '#F2C94C' 0 150
New-Card 'vram'    'VRAM'        'GB'  '#8FA2FF' 0 16

function Push-Card([string]$key, $val, [string]$fmt, [string]$sub, [string]$extra) {
    $c = $script:Cards[$key]
    $d = [double]::NaN
    if ($null -ne $val) { $d = [double]$val }
    $c.Hist.Add($d)
    while ($c.Hist.Count -gt 60) { $c.Hist.RemoveAt(0) }
    if (-not $win.IsVisible) { return }
    $c.Value.Text = Fmt $d $fmt
    if ($null -ne $sub) { $c.Sub.Text = $sub }
    if ($null -ne $extra) { $c.Extra.Text = $extra }
    $w = $c.Canvas.ActualWidth; $h = $c.Canvas.ActualHeight
    if ($w -lt 10 -or $h -lt 6) { return }
    $max = $c.Max
    foreach ($x in $c.Hist) { if (-not [double]::IsNaN($x) -and $x -gt $max) { $max = $x } }
    $min = $c.Min
    if ($max - $min -lt 1) { $max = $min + 1 }
    $pts = New-Object System.Windows.Media.PointCollection
    $n = $c.Hist.Count
    $step = $w / 59.0
    $x0 = $w - ($n - 1) * $step
    for ($i = 0; $i -lt $n; $i++) {
        $y = $c.Hist[$i]; if ([double]::IsNaN($y)) { $y = $min }
        $py = $h - 1 - (($y - $min) / ($max - $min)) * ($h - 3)
        $pts.Add((New-Object System.Windows.Point(($x0 + $i * $step), $py)))
    }
    $c.Line.Points = $pts
    $poly = $pts.Clone()
    if ($n -gt 0) { $poly.Add((New-Object System.Windows.Point($w, $h))); $poly.Add((New-Object System.Windows.Point($x0, $h))) }
    $c.Fill.Points = $poly
}

function Update-Cards {
    $hw = $script:Hw
    $f1 = $null; $f2 = $null
    if ($hw.Fans.Count -gt 1) { $f1 = $hw.Fans[0]; $f2 = $hw.Fans[1] }
    Push-Card 'cpuTemp' $hw.CpuTemp '0' $null $null
    $rpm1 = ''; if ($f1 -and $f1.Present -and $hw.Ec) { $rpm1 = "$($f1.Rpm) RPM" }
    $d1 = [double]::NaN; if ($f1 -and $hw.Ec) { $d1 = $f1.DutyPct }
    Push-Card 'cpuFan' $d1 '0' $null $rpm1
    Push-Card 'cpuClk' $hw.CpuClock '0' $null $null
    Push-Card 'cpuLoad' $hw.CpuLoad '0' $null $null
    Push-Card 'cpuPow' $hw.CpuPower '0' $null $null
    $script:Cards['ram'].Max = [Math]::Ceiling($hw.RamTotal)
    Push-Card 'ram' $hw.RamUsed '0.0' (' / ' + (Fmt $hw.RamTotal '0')) $null
    $gt = $hw.GpuTemp; $gx = ''
    if ([double]::IsNaN($gt) -and $f2 -and $hw.Ec -and -not [double]::IsNaN($f2.EcTemp)) { $gt = $f2.EcTemp; $gx = 'EC' }
    Push-Card 'gpuTemp' $gt '0' $null $gx
    $rpm2 = ''; if ($f2 -and $f2.Present -and $hw.Ec) { $rpm2 = "$($f2.Rpm) RPM" }
    $d2 = [double]::NaN; if ($f2 -and $hw.Ec) { $d2 = $f2.DutyPct }
    Push-Card 'gpuFan' $d2 '0' $null $rpm2
    Push-Card 'gpuClk' $hw.GpuClock '0' $null ('MEM ' + (Fmt $hw.MemClock '0'))
    Push-Card 'gpuLoad' $hw.GpuLoad '0' $null $null
    if (-not [double]::IsNaN($hw.GpuPowerLimit)) { $script:Cards['gpuPow'].Max = $hw.GpuPowerLimit }
    Push-Card 'gpuPow' $hw.GpuPower '0' (' / ' + (Fmt $hw.GpuPowerLimit '0') + ' W') $null
    if (-not [double]::IsNaN($hw.VramTotal)) { $script:Cards['vram'].Max = [Math]::Ceiling($hw.VramTotal) }
    Push-Card 'vram' $hw.VramUsed '0.0' (' / ' + (Fmt $hw.VramTotal '0')) $null
}

# ---------------------------------------------------------------- header / chips
function Update-Header {
    $hw = $script:Hw
    $ui.TxtGpuName.Text = $hw.GpuName
    $parts = @()
    if ($hw.Driver) { $parts += "Driver $($hw.Driver)" }
    if (-not [double]::IsNaN($hw.DefaultPowerW)) { $parts += ('Stock {0:0} W' -f $hw.DefaultPowerW) }
    $parts += $CpuName
    $ui.TxtGpuSub.Text = ($parts -join '  ·  ')
    $ui.TxtModel.Text = $Model
    $ui.TxtVersion.Text = "v$AppVersion"

    if ($hw.Ec -and $hw.Msr) { $ui.DotPawn.Fill = $Green; $ui.ChipPawn.Text = (T 'PawnIO ready') }
    elseif ($hw.Ec -or $hw.Msr) { $ui.DotPawn.Fill = $Yellow; $ui.ChipPawn.Text = (T 'PawnIO partial') }
    else { $ui.DotPawn.Fill = $Red; $ui.ChipPawn.Text = (T 'PawnIO missing') }

    if ([ClevoTune.NvApi]::Ready) { $ui.DotNv.Fill = $Green; $ui.ChipNv.Text = (T 'NVAPI ready') } else { $ui.DotNv.Fill = $Red; $ui.ChipNv.Text = (T 'NVAPI unavailable') }
    if ($IsAdmin) { $ui.DotAdmin.Fill = $Green; $ui.ChipAdmin.Text = (T 'Administrator') } else { $ui.DotAdmin.Fill = $Red; $ui.ChipAdmin.Text = (T 'No admin') }
    Update-AutoChip

    $drv = $false; try { $drv = [ClevoTune.PawnIo]::DriverPresent() } catch { }
    $lines = @()
    $lines += (T 'PawnIO driver: {0}') -f $(if ($drv) { T 'installed' } else { T 'NOT installed' })
    $lines += (T 'EC / fans (LpcACPIEC.bin): {0}') -f $(if ($hw.Ec) { 'OK' } else { T $hw.EcError })
    $lines += (T 'CPU temp/power (IntelMSR.bin): {0}') -f $(if ($hw.Msr) { 'OK' } else { T $hw.MsrError })
    $lines += 'NVML: ' + $(if ($hw.NvmlOk) { 'OK' } else { $hw.NvmlError }) + '    NVAPI: ' + $(if ([ClevoTune.NvApi]::Ready) { 'OK' } else { [ClevoTune.NvApi]::LastError })
    $ui.TxtPawnStatus.Text = ($lines -join "`n")
    $ui.TxtPaths.Text = "Script: $Self`n" + ((T 'Modules: {0}') -f $ModDir) + "`n" + ((T 'Settings: {0}') -f $CfgPath) + "`n" + 'Language: ' + $script:LangDir
}

function Update-AutoChip {
    $lp = Get-LastProfile
    if (($script:Cfg.autoApply -or $script:Cfg.applyOnOpen) -and $lp) { $ui.DotAuto.Fill = $Green; $ui.ChipAuto.Text = ((T 'Auto-apply: {0}') -f $lp.name) }
    else { $ui.DotAuto.Fill = $Grey; $ui.ChipAuto.Text = (T 'Auto-apply: off') }
}

# ---------------------------------------------------------------- GPU tuning
$script:Loading = $true
$script:OI = $null
$script:AppliedLock = [int]$script:Cfg.lastLock

function Clamp([double]$v, [double]$a, [double]$b) { return [Math]::Max($a, [Math]::Min($b, $v)) }

function Init-Tuning {
    $hw = $script:Hw
    $script:Loading = $true
    # power limit: NVML first, NVAPI power target (% of default) as the laptop-friendly fallback
    $pp = [ClevoTune.NvApi]::GetPowerPolicy()
    $script:PP = $pp
    $defW = $hw.DefaultPowerW
    $script:PowerViaNvapi = $pp.Valid -and -not [double]::IsNaN($defW) -and ($pp.MaxPct - $pp.MinPct) -ge 1
    $script:PowerCapable = $hw.PowerLimitSupported -or $script:PowerViaNvapi
    if ($script:PowerCapable -and -not $script:PowerViaNvapi -and [string]$script:Cfg.powerLocked -and [string]$script:Cfg.powerLocked -eq [string]$hw.Driver) {
        $script:PowerCapable = $false   # already confirmed locked on this driver version
    }
    $minW = $hw.MinPowerW; $maxW = $hw.MaxPowerW
    if ($script:PowerViaNvapi) {
        $nMin = $defW * $pp.MinPct / 100; $nMax = $defW * $pp.MaxPct / 100
        if ([double]::IsNaN($minW) -or -not $hw.PowerLimitSupported) { $minW = $nMin; $maxW = $nMax }
        Log ('NVAPI power target: {0:0}–{1:0} % (default {2:0} %, now {3}) = {4:0}–{5:0} W' -f $pp.MinPct, $pp.MaxPct, $pp.DefPct, $(if ([double]::IsNaN($pp.CurPct)) { '?' } else { '{0:0} %' -f $pp.CurPct }), $nMin, $nMax)
    } elseif ([ClevoTune.NvApi]::Ready) {
        if ($pp.InfoStatus -eq 0) { Log 'NVAPI power target: no client power policies on this GPU' }
        else { Log ('NVAPI power target: ' + [ClevoTune.NvApi]::StatusText($pp.InfoStatus)) }
    }
    $mvLocked = ([string]$script:Cfg.powerLocked -eq ([string]$hw.Driver + '|mvolt'))
    if (-not $script:PowerCapable -and $script:MVolt -and -not $mvLocked -and -not [double]::IsNaN($defW)) {
        $script:PowerCapable = $true     # mVolt+ can change it when the driver blocks NVML/NVAPI
        if ([double]::IsNaN($minW) -or [double]::IsNaN($maxW) -or $maxW - $minW -lt 1) { $minW = $defW * 0.5; $maxW = $defW * 1.2 }
    }
    $pm = ([string]$script:Cfg.powerMax).Split('|')
    if ($pm.Count -eq 2 -and $pm[0] -eq [string]$hw.Driver -and [double]$pm[1] -gt 0 -and -not [double]::IsNaN($maxW)) {
        $maxW = [Math]::Min($maxW, [double]$pm[1])   # measured: the card can't go above this
    }
    if ($script:PowerCapable) {
        $ui.SlPower.IsEnabled = $true
        $ui.SlPower.Minimum = [Math]::Floor($minW)
        $ui.SlPower.Maximum = [Math]::Ceiling($maxW)
        $ui.LblPowerMin.Text = ('{0:0} W' -f $minW)
        $ui.LblPowerMax.Text = ('{0:0} W' -f $maxW)
        if (-not [double]::IsNaN($hw.GpuPowerLimit)) { $ui.SlPower.Value = [Math]::Round($hw.GpuPowerLimit) } else { $ui.SlPower.Value = [Math]::Round($hw.DefaultPowerW) }
    } else {
        $ui.SlPower.IsEnabled = $false
        $ui.LblPowerMin.Text = ''; $ui.LblPowerMax.Text = ''
    }

    $oi = [ClevoTune.NvApi]::GetOffsets()
    $script:OI = $oi
    if ($oi.Status -eq 0 -and $oi.CoreFound) {
        $mn = Clamp $oi.CoreMin -1000 0; $mx = Clamp $oi.CoreMax 0 1000
        if ($mx -le $mn) { $mn = -300; $mx = 300 }
        $ui.SlCore.Minimum = $mn; $ui.SlCore.Maximum = $mx
        $ui.LblCoreMin.Text = "$(Signed $mn) MHz"; $ui.LblCoreMax.Text = "$(Signed $mx) MHz"
        $ui.SlCore.Value = $oi.CoreMHz
        $ui.SlCore.IsEnabled = $oi.CoreEditable
    } else { $ui.SlCore.IsEnabled = [ClevoTune.NvApi]::Ready }
    if ($oi.Status -eq 0 -and $oi.MemFound) {
        $mn = Clamp $oi.MemMin -1000 0; $mx = Clamp $oi.MemMax 0 3000
        if ($mx -le $mn) { $mn = -500; $mx = 1500 }
        $ui.SlMem.Minimum = $mn; $ui.SlMem.Maximum = $mx
        $ui.LblMemMin.Text = "$(Signed $mn) MHz"; $ui.LblMemMax.Text = "$(Signed $mx) MHz"
        $ui.SlMem.Value = $oi.MemMHz
        $ui.SlMem.IsEnabled = $oi.MemEditable
    } else { $ui.SlMem.IsEnabled = [ClevoTune.NvApi]::Ready }

    $ui.ChkLock.IsEnabled = $hw.NvmlOk
    $ui.ChkLock.IsChecked = ($script:AppliedLock -gt 0)
    if ($script:AppliedLock -gt 0) { $ui.SlLock.Value = $script:AppliedLock }
    $ui.SlLock.IsEnabled = [bool]$ui.ChkLock.IsChecked
    $ui.SlVolt.IsEnabled = [bool]$script:MVolt
    $ui.SlVolt.Value = $script:AppliedVolt
    $script:Loading = $false
    Update-TuneTexts
    Update-Readback
}

function Update-TuneTexts {
    $hw = $script:Hw
    if ($ui.SlPower.IsEnabled) {
        $v = $ui.SlPower.Value
        $ui.ValPower.Text = ('{0:0} W' -f $v)
        if (-not [double]::IsNaN($hw.DefaultPowerW)) { $ui.DeltaPower.Text = ((T '{0} W vs stock') -f (Signed ($v - $hw.DefaultPowerW))) }
    } else {
        $ui.ValPower.Text = (Fmt $hw.GpuPowerLimit '0') + ' W'
        $ui.DeltaPower.Text = (T 'locked by vBIOS/driver')
    }
    $ui.ValCore.Text = "$(Signed $ui.SlCore.Value) MHz"; $ui.DeltaCore.Text = ((T '{0} MHz vs stock') -f (Signed $ui.SlCore.Value))
    $ui.ValMem.Text = "$(Signed $ui.SlMem.Value) MHz"; $ui.DeltaMem.Text = ((T '{0} MHz vs stock') -f (Signed $ui.SlMem.Value))
    if ($ui.ChkLock.IsChecked) { $ui.ValLock.Text = ('{0:0} MHz' -f $ui.SlLock.Value) } else { $ui.ValLock.Text = (T 'off') }
    $ui.ValVolt.Text = "$(Signed $ui.SlVolt.Value) mV"
    $ui.DeltaVolt.Text = ((T '{0} mV vs stock') -f (Signed $ui.SlVolt.Value))
}

function Update-Readback {
    $hw = $script:Hw
    if ($script:MVolt) { $ui.CardVolt.Text = ((T 'applied: {0} mV') -f (Signed $script:AppliedVolt)) } else { $ui.CardVolt.Text = (T 'requires mVolt+') }
    if ($script:PowerCapable) {
        $ui.CardPower.Text = ((T 'on card: {0} W') -f (Fmt $hw.GpuPowerLimit '0'))
        if (-not [double]::IsNaN($script:MVoltPowerW)) { $ui.CardPower.Text = ((T 'on card: {0} W') -f (Fmt $script:MVoltPowerW '0')) + ' (mVolt+)' }
    }
    elseif ($hw.NvmlOk) { $ui.CardPower.Text = ((T 'on card: {0} W (not adjustable)') -f (Fmt $hw.GpuPowerLimit '0')) }
    else { $ui.CardPower.Text = (T 'NVML unavailable') }
    $oi = [ClevoTune.NvApi]::GetOffsets()
    $script:OI = $oi
    if ($oi.Status -eq 0) {
        if ($oi.CoreFound) { $ui.CardCore.Text = ((T 'on card: {0} MHz') -f (Signed $oi.CoreMHz)) + $(if (-not $oi.CoreEditable) { ' ' + (T '(locked)') } else { '' }) }
        if ($oi.MemFound) { $ui.CardMem.Text = ((T 'on card: {0} MHz') -f (Signed $oi.MemMHz)) + $(if (-not $oi.MemEditable) { ' ' + (T '(locked)') } else { '' }) }
    } else {
        $t = (T 'on card: {0}') -f [ClevoTune.NvApi]::StatusText($oi.Status)
        $ui.CardCore.Text = $t; $ui.CardMem.Text = $t
    }
    if ($script:AppliedLock -gt 0) { $ui.CardLock.Text = ((T 'applied: {0} MHz') -f $script:AppliedLock) } else { $ui.CardLock.Text = (T 'applied: off') }
}

function Apply-Tuning([int]$power, [int]$core, [int]$mem, [int]$lock, [string]$label, [int]$volt = 0) {
    $hw = $script:Hw
    $ok = $true; $done = @()
    $mvPower = 0
    # a profile above the measured ceiling of this card is reduced to it (avoids retrying every start)
    $pm = ([string]$script:Cfg.powerMax).Split('|')
    if ($power -gt 0 -and $pm.Count -eq 2 -and $pm[0] -eq [string]$hw.Driver -and [double]$pm[1] -gt 0 -and $power -gt [double]$pm[1]) { $power = [int][double]$pm[1] }
    $curW = $hw.GpuPowerLimit
    if (-not [double]::IsNaN($script:MVoltPowerW)) { $curW = $script:MVoltPowerW }
    if ($power -gt 0 -and $script:PowerCapable -and -not [double]::IsNaN($curW) -and [Math]::Abs($power - $curW) -lt 0.5) {
        $power = 0   # already enforced: nothing to change
    }
    if ($power -gt 0 -and $script:PowerCapable) {
        $how = ''; $pdone = $false
        $known = [string]$script:Cfg.powerLocked -and ([string]$script:Cfg.powerLocked).Split('|')[0] -eq [string]$hw.Driver
        if (-not $known) {
            $st = 999
            if ($hw.PowerLimitSupported) { $st = $hw.SetPowerLimitW($power); $how = 'NVML ' + $hw.NvmlText($st) }
            if ($st -eq 0) { $pdone = $true }
            elseif ([ClevoTune.NvApi]::Ready -and -not [double]::IsNaN($hw.DefaultPowerW)) {
                $pp = $script:PP
                $pct = $power / $hw.DefaultPowerW * 100
                if ($script:PowerViaNvapi) { $pct = [Math]::Max($pp.MinPct, [Math]::Min($pp.MaxPct, $pct)) }
                $st2 = [ClevoTune.NvApi]::SetPowerTarget($pct)
                $how += $(if ($how) { ' → ' } else { '' }) + ('NVAPI {0:0.#} %: ' -f $pct) + [ClevoTune.NvApi]::StatusText($st2)
                if ($st2 -eq 0) { $pdone = $true }
            }
            if (-not $pdone) { $script:Cfg.powerLocked = [string]$hw.Driver; $script:Dirty = $true }
        }
        if ($pdone) {
            Log ((T 'Power {0} W: {1}') -f $power, $how)
            $done += "$power W"; $script:MVoltPowerW = [double]::NaN
        } elseif ($script:MVolt -and -not [double]::IsNaN($hw.DefaultPowerW)) {
            if ($how) { Log ((T 'Power {0} W: {1}') -f $power, ($how + ' → mVolt+')) }
            $mvPower = $power
        } else {
            if ($how) { Log ((T 'Power {0} W: {1}') -f $power, $how) }
            $ok = $false
            $script:PowerCapable = $false
            $ui.SlPower.IsEnabled = $false
            $ui.LblPowerMin.Text = ''; $ui.LblPowerMax.Text = ''
            Log (T 'The power limit is locked on this GPU (vBIOS/driver), so the slider was disabled. Use mVolt+ to change power limits.')
        }
    }
    if ([ClevoTune.NvApi]::Ready) {
        $oi = $script:OI
        $known = ($oi -and $oi.Status -eq 0)
        if (-not $known -or ($oi.CoreFound -and $oi.CoreEditable)) {
            $st = [ClevoTune.NvApi]::SetOffset(0, $core)
            Log ((T 'Core offset {0} MHz: {1}') -f (Signed $core), [ClevoTune.NvApi]::StatusText($st))
            if ($st -eq 0) { $done += ((T 'core {0}') -f (Signed $core)) } else { $ok = $false }
        } elseif ($core -ne 0) { Log (T 'Core offset: locked by the driver on this GPU') }
        if (-not $known -or ($oi.MemFound -and $oi.MemEditable)) {
            $st = [ClevoTune.NvApi]::SetOffset(4, $mem)
            Log ((T 'Memory offset {0} MHz: {1}') -f (Signed $mem), [ClevoTune.NvApi]::StatusText($st))
            if ($st -eq 0) { $done += "mem $(Signed $mem)" } else { $ok = $false }
        } elseif ($mem -ne 0) { Log (T 'Memory offset: locked by the driver on this GPU') }
    } else { Log ((T 'NVAPI unavailable: {0}') -f [ClevoTune.NvApi]::LastError); $ok = $false }
    if ($hw.NvmlOk) {
        if ($lock -gt 0) {
            $st = $hw.LockClocks(210, $lock)
            Log ((T 'Clock limit {0} MHz: {1}') -f $lock, $hw.NvmlText($st))
            if ($st -eq 0) { $script:AppliedLock = $lock; $done += ((T 'limit {0}') -f $lock) } else { $ok = $false }
        } else {
            $st = $hw.ResetClocks()
            if ($st -eq 0) { $script:AppliedLock = 0 }
            elseif ($script:AppliedLock -gt 0) { Log ((T 'Remove clock limit: {0}') -f $hw.NvmlText($st)); $ok = $false }
        }
        $script:Cfg.lastLock = $script:AppliedLock; $script:Dirty = $true
    }
    # mVolt+: power and voltage in separate calls, so one refused option doesn't block the other
    if ($mvPower -gt 0) {
        $def = $hw.DefaultPowerW
        $runs = @()
        if ($mvPower -lt $def - 0.5) { $runs += ,@('--power-cap-watts', (Inv '{0:0.###}' $mvPower)) }
        elseif ($mvPower -le $def + 0.5) { $runs += ,@('--return-to-percentage') }
        else { $runs += ,@('--power', [string][int][Math]::Round($mvPower / $def * 100)); $runs += ,@('--power-cap-watts', (Inv '{0:0.###}' $mvPower)) }
        $r = $null
        foreach ($cmd in $runs) {
            $r = Invoke-MVolt $cmd
            Log ((T 'mVolt+: {0}') -f ('[' + ($cmd -join ' ') + '] exit ' + $r.Code + $(if ($r.Out) { ' — ' + $r.Out } else { '' })))
            if ($r.Code -eq 0) { break }
        }
        if ($r -and $r.Code -eq 0) {
            $s = Get-MVoltStatus
            if ($s -and $s.power_limits -and $s.power_limits.enforced_mw) { $script:MVoltPowerW = [double]$s.power_limits.enforced_mw / 1000 } else { $script:MVoltPowerW = [double]$mvPower }
            Log ((T 'mVolt+: {0}') -f ('power enforced ' + (Fmt $script:MVoltPowerW '0') + ' W'))
            if ($script:MVoltPowerW -lt $mvPower - 1) {
                # accepted, but the card won't go that high: remember the real ceiling for this driver
                $ceil = [int][Math]::Round([Math]::Max($script:MVoltPowerW, $def))
                $script:Cfg.powerMax = [string]$hw.Driver + '|' + $ceil; $script:Dirty = $true
                $ui.SlPower.Maximum = $ceil; $ui.LblPowerMax.Text = ('{0:0} W' -f $ceil)
                Log ((T 'The card still enforces {0} W: on this GPU the power limit can be lowered, but not raised above {1} W. The slider maximum is now {1} W.') -f (Fmt $script:MVoltPowerW '0'), $ceil)
                $ok = $false
            } else { $done += "$mvPower W" }
        } else {
            $ok = $false
            $script:Cfg.powerLocked = [string]$hw.Driver + '|mvolt'; $script:Dirty = $true
            $script:PowerCapable = $false
            $ui.SlPower.IsEnabled = $false
            $ui.LblPowerMin.Text = ''; $ui.LblPowerMax.Text = ''
            Log (T 'The power limit is locked on this GPU: NVML, NVAPI and mVolt+ all refused it, so the slider was disabled.')
        }
    }
    if ($script:MVolt -and ($volt -ne $script:AppliedVolt)) {
        $vArg = Inv '{0}' $volt
        $r = Invoke-MVolt @('--core-vdemand', $vArg)
        Log ((T 'mVolt+: {0}') -f ("[--core-vdemand $vArg] exit " + $r.Code + $(if ($r.Out) { ' — ' + $r.Out } else { '' })))
        if ($r.Code -eq 0) {
            $script:AppliedVolt = $volt; $script:Cfg.lastVolt = $volt; $script:Dirty = $true
            $done += ((T 'voltage {0} mV') -f (Signed $volt))
        } else { $ok = $false }
    }
    $when = (Get-Date).ToString('HH:mm:ss')
    $txt = "$label " + ($done -join ' / ') + "  ($when)"
    if ($ok) { Set-Status $txt $Green; $ui.TxtLive.Text = (T 'Applied to card') } else { Set-Status ((T '{0} — see log') -f $txt) $Yellow; $ui.TxtLive.Text = (T 'Applied with warnings') }
    Update-Readback
}

$ui.SlPower.Add_ValueChanged({ Update-TuneTexts })
$ui.SlCore.Add_ValueChanged({ Update-TuneTexts })
$ui.SlMem.Add_ValueChanged({ Update-TuneTexts })
$ui.SlLock.Add_ValueChanged({ Update-TuneTexts })
$ui.SlVolt.Add_ValueChanged({ Update-TuneTexts })
$ui.ChkLock.Add_Click({ $ui.SlLock.IsEnabled = [bool]$ui.ChkLock.IsChecked; Update-TuneTexts })

function Current-Sliders {
    $p = 0; if ($ui.SlPower.IsEnabled) { $p = [int]$ui.SlPower.Value }
    $l = 0; if ($ui.ChkLock.IsChecked) { $l = [int]$ui.SlLock.Value }
    $v = 0; if ($script:MVolt) { $v = [int]$ui.SlVolt.Value }
    return [pscustomobject]@{ power = $p; core = [int]$ui.SlCore.Value; mem = [int]$ui.SlMem.Value; lock = $l; volt = $v }
}

$ui.BtnApply.Add_Click({
    try { $s = Current-Sliders; Apply-Tuning $s.power $s.core $s.mem $s.lock (T 'Applied') $s.volt } catch { Log ((T 'Error: {0}') -f $_.Exception.Message) }
})
$ui.BtnStock.Add_Click({
    try {
        $hw = $script:Hw
        $script:Loading = $true
        if ($ui.SlPower.IsEnabled -and -not [double]::IsNaN($hw.DefaultPowerW)) { $ui.SlPower.Value = [Math]::Round($hw.DefaultPowerW) }
        $ui.SlCore.Value = 0; $ui.SlMem.Value = 0; $ui.SlVolt.Value = 0; $ui.ChkLock.IsChecked = $false; $ui.SlLock.IsEnabled = $false
        $script:Loading = $false
        Update-TuneTexts
        $s = Current-Sliders
        Apply-Tuning $s.power 0 0 0 (T 'Stock:') 0
    } catch { Log ((T 'Error: {0}') -f $_.Exception.Message) }
})
$ui.BtnRefresh.Add_Click({ Update-Readback; Set-Status (T 'Values re-read from the card') $Green })

# ---------------------------------------------------------------- profiles
function Profile-Text($p) {
    $a = @()
    if ([int]$p.power -gt 0) { $a += "$($p.power) W" } else { $a += (T 'stock power') }
    $a += ((T 'core {0}') -f (Signed $p.core)); $a += "mem $(Signed $p.mem)"
    if ([int]$p.lock -gt 0) { $a += (((T 'limit {0}') -f $p.lock) + ' MHz') }
    if ([int]$p.volt -ne 0) { $a += ((T 'voltage {0} mV') -f (Signed ([int]$p.volt))) }
    return ($a -join ' / ') + '   —   ' + (T 'Load fills the sliders, Apply writes them')
}
function Get-Profile([string]$name) { foreach ($p in $script:Cfg.profiles) { if ($p.name -eq $name) { return $p } }; return $null }
function Get-LastProfile {
    # the profile most recently created/saved by the user; the built-in 'Stock' alone does not count
    if ($script:Cfg.lastProfile) { $p = Get-Profile ([string]$script:Cfg.lastProfile); if ($p) { return $p } }
    $all = @($script:Cfg.profiles)
    if ($all.Count -gt 1) { return $all[$all.Count - 1] }
    if ($all.Count -eq 1 -and [string]$all[0].name -ne 'Stock') { return $all[0] }
    return $null
}
function Fill-Profiles {
    $script:Loading = $true
    $ui.CmbProfiles.Items.Clear()
    foreach ($p in $script:Cfg.profiles) { [void]$ui.CmbProfiles.Items.Add([string]$p.name) }
    $ui.CmbProfiles.SelectedItem = [string]$script:Cfg.selectedProfile
    if ($ui.CmbProfiles.SelectedIndex -lt 0 -and $ui.CmbProfiles.Items.Count -gt 0) { $ui.CmbProfiles.SelectedIndex = 0; $script:Cfg.selectedProfile = [string]$ui.CmbProfiles.SelectedItem }
    $script:Loading = $false
    $p = Get-Profile $script:Cfg.selectedProfile
    if ($p) { $ui.TxtProfileInfo.Text = Profile-Text $p }
    Update-AutoChip
    Build-TrayMenu
}
$ui.CmbProfiles.Add_SelectionChanged({
    if ($script:Loading -or -not $ui.CmbProfiles.SelectedItem) { return }
    $script:Cfg.selectedProfile = [string]$ui.CmbProfiles.SelectedItem
    $p = Get-Profile $script:Cfg.selectedProfile
    if ($p) { $ui.TxtProfileInfo.Text = Profile-Text $p }
    $script:Dirty = $true
    Update-AutoChip
})
function Load-ProfileToSliders($p) {
    $hw = $script:Hw
    $script:Loading = $true
    if ($ui.SlPower.IsEnabled) {
        if ([int]$p.power -gt 0) { $ui.SlPower.Value = [int]$p.power } elseif (-not [double]::IsNaN($hw.DefaultPowerW)) { $ui.SlPower.Value = [Math]::Round($hw.DefaultPowerW) }
    }
    $ui.SlCore.Value = [int]$p.core; $ui.SlMem.Value = [int]$p.mem
    $ui.ChkLock.IsChecked = ([int]$p.lock -gt 0); $ui.SlLock.IsEnabled = [bool]$ui.ChkLock.IsChecked
    if ([int]$p.lock -gt 0) { $ui.SlLock.Value = [int]$p.lock }
    $ui.SlVolt.Value = [int]$p.volt
    $script:Loading = $false
    Update-TuneTexts
}
$ui.BtnLoad.Add_Click({
    $p = Get-Profile ([string]$ui.CmbProfiles.SelectedItem)
    if ($p) { Load-ProfileToSliders $p; Set-Status ((T "Profile '{0}' loaded into the sliders — press Apply") -f $p.name) $Green }
})
$ui.BtnSaveAs.Add_Click({
    $def = [string]$ui.CmbProfiles.SelectedItem
    $name = [Microsoft.VisualBasic.Interaction]::InputBox((T 'Profile name:'), $AppName, $def)
    $name = "$name".Trim()
    if (-not $name) { return }
    $s = Current-Sliders
    $p = Get-Profile $name
    if ($p) {
        $r = [System.Windows.MessageBox]::Show(((T "Replace profile '{0}'?") -f $name), $AppName, 'YesNo', 'Question')
        if ($r -ne 'Yes') { return }
        $p.power = $s.power; $p.core = $s.core; $p.mem = $s.mem; $p.lock = $s.lock
        $p | Add-Member -NotePropertyName volt -NotePropertyValue $s.volt -Force
    } else {
        $script:Cfg.profiles = @($script:Cfg.profiles) + [pscustomobject]@{ name = $name; power = $s.power; core = $s.core; mem = $s.mem; lock = $s.lock; volt = $s.volt }
    }
    $script:Cfg.selectedProfile = $name
    $script:Cfg.lastProfile = $name
    Save-Config
    Fill-Profiles
    Set-Status ((T "Profile '{0}' saved") -f $name) $Green
})
$ui.BtnDelete.Add_Click({
    $name = [string]$ui.CmbProfiles.SelectedItem
    if (-not $name) { return }
    if (@($script:Cfg.profiles).Count -le 1) { Set-Status (T 'At least one profile must exist') $Yellow; return }
    $r = [System.Windows.MessageBox]::Show(((T "Delete profile '{0}'?") -f $name), $AppName, 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
    $script:Cfg.profiles = @($script:Cfg.profiles | Where-Object { $_.name -ne $name })
    $script:Cfg.selectedProfile = [string]$script:Cfg.profiles[0].name
    if ([string]$script:Cfg.lastProfile -eq $name) { $script:Cfg.lastProfile = '' }
    Save-Config
    Fill-Profiles
})

# ---------------------------------------------------------------- autostart (scheduled task)
$TaskName = 'ClevoTune'
function Test-AutoStart { try { return [bool](Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) } catch { return $false } }
function Set-AutoStart([bool]$on) {
    if ($on) {
        $p = $Self.Replace("'", "''")
        $arg = "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command `"`$env:CT_SELF='$p'; `$env:CT_ARGS='/tray'; iex ([IO.File]::ReadAllText(`$env:CT_SELF))`""
        $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        if ($env:CT_EXE -eq '1') { $act = New-ScheduledTaskAction -Execute $Self -Argument '/tray' -WorkingDirectory $SelfDir }
        else { $act = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $arg }
        $trg = New-ScheduledTaskTrigger -AtLogOn -User $user
        $trg.Delay = 'PT15S'
        $prn = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
        $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $TaskName -Action $act -Trigger $trg -Principal $prn -Settings $set -Description (T 'ClevoTune: GPU profile + fan curves at logon') -Force | Out-Null
    } else {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    }
}
$ui.ChkApplyOnOpen.Add_Click({
    $script:Cfg.applyOnOpen = [bool]$ui.ChkApplyOnOpen.IsChecked
    Save-Config
    Update-AutoChip
})
function Set-StartWithWindows([bool]$want) {
    try {
        Set-AutoStart $want
        $script:Cfg.autoApply = $want
        Save-Config
        $lp = Get-LastProfile; $pn = $(if ($lp) { $lp.name } else { 'Stock' })
        Log $(if ($want) { (T "Start with Windows enabled (profile '{0}')") -f $pn } else { T 'Start with Windows disabled' })
        Set-Status $(if ($want) { T 'Starts with Windows at sign-in' } else { T 'Start with Windows disabled' }) $Green
    } catch {
        Log ((T 'Scheduled task failed: {0}') -f $_.Exception.Message)
        Set-Status (T 'Could not create the scheduled task — see log') $Red
    }
    # keep every copy of the option in sync with the real state of the task
    $on = [bool]$script:Cfg.autoApply -and (Test-AutoStart)
    $script:Cfg.autoApply = $on
    $ui.ChkAutoApply.IsChecked = $on
    $ui.ChkStartup.IsChecked = $on
    Update-AutoChip
    Build-TrayMenu
}
$ui.ChkAutoApply.Add_Click({ Set-StartWithWindows ([bool]$ui.ChkAutoApply.IsChecked) })
$ui.ChkStartup.Add_Click({ Set-StartWithWindows ([bool]$ui.ChkStartup.IsChecked) })

# ---------------------------------------------------------------- fans tab
$script:SelFan = $null
$script:FanItems = @{}
$script:Drag = $null
$script:PtSig = ''
function Mode-Name([int]$i) { return T (@('Auto (EC)', 'Curve', 'Fixed')[$i]) }

function Build-FanList {
    $ui.FanList.Children.Clear()
    $script:FanItems = @{}
    $hw = $script:Hw
    $enabled = [bool]$hw.Ec
    foreach ($c in 'CmbFanMode', 'CmbFanSource', 'CmbPreset', 'SlFixed', 'GridPoints', 'BtnAddPt', 'BtnDelPt', 'BtnAllAuto', 'ChkCfcGrid', 'BtnImportCfc', 'BtnExportCfc', 'BtnSaveCurves') { $ui[$c].IsEnabled = $enabled }
    if (-not $enabled) {
        $ui.TxtFanNote.Text = ((T 'Fan control unavailable: {0}. See the Settings tab.') -f (T $hw.EcError))
        $ui.TxtFanNote.Foreground = $Yellow
    } else {
        $ui.TxtFanNote.Text = (T 'Closing the app returns the fans to the EC''s automatic control.')
        $ui.TxtFanNote.Foreground = Brush '#8B9198'
    }
    $first = $null
    foreach ($f in $hw.Fans) {
        if ($enabled -and -not $f.Present) { continue }
        $b = New-Object System.Windows.Controls.Border
        $b.CornerRadius = New-Object System.Windows.CornerRadius 6
        $b.Padding = Thick 12 9 12 9; $b.Margin = Thick 0 0 10 8; $b.Cursor = 'Hand'
        $b.BorderThickness = Thick 1 1 1 1; $b.BorderBrush = Brush '#30353B'; $b.Background = Brush '#101315'
        $sp = New-Object System.Windows.Controls.StackPanel
        $t = New-Object System.Windows.Controls.TextBlock; $t.Text = ((T 'Fan {0} · {1}') -f $f.Index, $f.Name); $t.FontSize = 14
        $s = New-Object System.Windows.Controls.TextBlock; $s.Foreground = Brush '#8B9198'; $s.FontSize = 12; $s.Margin = Thick 0 3 0 0
        [void]$sp.Children.Add($t); [void]$sp.Children.Add($s)
        $b.Child = $sp
        $b.Tag = $f
        $b.Add_MouseLeftButtonUp({ param($sender, $e) Select-Fan $sender.Tag })
        [void]$ui.FanList.Children.Add($b)
        $script:FanItems[$f.Index] = @{ Border = $b; Sub = $s }
        if (-not $first) { $first = $f }
    }
    $sel = $first
    if ($script:SelFan) { foreach ($f in $hw.Fans) { if ($f.Index -eq $script:SelFan.Index -and $script:FanItems.ContainsKey($f.Index)) { $sel = $f } } }
    if ($sel) { Select-Fan $sel }
}

function Select-Fan($f) {
    $script:SelFan = $f
    $script:Loading = $true
    foreach ($k in $script:FanItems.Keys) {
        $it = $script:FanItems[$k]
        if ($k -eq $f.Index) { $it.Border.BorderBrush = $Green; $it.Border.Background = Brush '#14231F' } else { $it.Border.BorderBrush = Brush '#30353B'; $it.Border.Background = Brush '#101315' }
    }
    $ui.CmbFanMode.SelectedIndex = $f.Mode
    $ui.CmbFanSource.SelectedIndex = $f.Source
    $ui.CmbPreset.SelectedIndex = -1
    $ui.SlFixed.Value = $f.Fixed
    $ui.ValFixed.Text = "$($f.Fixed) %"
    $ui.GridPoints.ItemsSource = $f.Points
    $script:Loading = $false
    Update-FanPanels
    Update-GridLock
    Update-AxisUi
    Draw-Curve
}

function Update-FanPanels {
    $f = $script:SelFan
    if (-not $f) { return }
    if ($f.Mode -eq 2) { $ui.PnlFixed.Visibility = 'Visible' } else { $ui.PnlFixed.Visibility = 'Collapsed' }
    $ui.PnlCurve.Opacity = $(if ($f.Mode -eq 1) { 1.0 } else { 0.45 })
    $ui.CmbFanSource.IsEnabled = ($f.Mode -eq 1 -and [bool]$script:Hw.Ec)
}

function Sort-Points($f) {
    $arr = @($f.Points | Sort-Object Temp)
    $same = $true
    for ($i = 0; $i -lt $arr.Count; $i++) { if (-not [object]::ReferenceEquals($arr[$i], $f.Points[$i])) { $same = $false; break } }
    if ($same) { return }
    $f.Points.Clear()
    foreach ($p in $arr) { $f.Points.Add($p) }
}

$ui.CmbFanMode.Add_SelectionChanged({
    if ($script:Loading -or -not $script:SelFan -or $ui.CmbFanMode.SelectedIndex -lt 0) { return }
    $script:SelFan.Mode = $ui.CmbFanMode.SelectedIndex
    Log ((T 'Fan {0} ({1}): mode {2}') -f $script:SelFan.Index, $script:SelFan.Name, (Mode-Name $script:SelFan.Mode))
    $script:Dirty = $true
    Update-FanPanels; Draw-Curve
})
$ui.CmbFanSource.Add_SelectionChanged({
    if ($script:Loading -or -not $script:SelFan -or $ui.CmbFanSource.SelectedIndex -lt 0) { return }
    $script:SelFan.Source = $ui.CmbFanSource.SelectedIndex
    $script:SelFan.EffTemp = [double]::NaN
    $script:SelFan.LoadEma = [double]::NaN
    $src = $ui.CmbFanSource.SelectedItem.Content
    Log ((T 'Fan {0} ({1}): input {2}') -f $script:SelFan.Index, $script:SelFan.Name, $src)
    Update-AxisUi
    Draw-Curve
    $script:Dirty = $true
})
$ui.CmbPreset.Add_SelectionChanged({
    if ($script:Loading -or -not $script:SelFan -or $ui.CmbPreset.SelectedIndex -lt 0) { return }
    $f = $script:SelFan
    $f.Points.Clear()
    $set = $Presets; if ($f.IsLoad) { $set = $LoadPresets }
    foreach ($q in (New-Pts $set[$ui.CmbPreset.SelectedIndex])) { $f.Points.Add((New-Object ClevoTune.CurvePoint([int]$q.t, [int]$q.p))) }
    if ($script:Cfg.cfcGrid) { Set-GridPoints $f (Get-GridValues $f) }
    $script:Dirty = $true
    Draw-Curve
})
$ui.SlFixed.Add_ValueChanged({
    $ui.ValFixed.Text = ('{0:0} %' -f $ui.SlFixed.Value)
    if ($script:Loading -or -not $script:SelFan) { return }
    $script:SelFan.Fixed = [int]$ui.SlFixed.Value
    $script:Dirty = $true
})
$ui.BtnAddPt.Add_Click({
    $f = $script:SelFan; if (-not $f) { return }
    Sort-Points $f
    $t = 60; $p = 50
    if ($f.Points.Count -gt 0) { $last = $f.Points[$f.Points.Count - 1]; $t = [Math]::Min(105, $last.Temp + 5); $p = [Math]::Min(100, $last.Pct + 10) }
    $f.Points.Add((New-Object ClevoTune.CurvePoint($t, $p)))
    $script:Dirty = $true; Draw-Curve
})
$ui.BtnDelPt.Add_Click({
    $f = $script:SelFan; if (-not $f -or $f.Points.Count -le 1) { return }
    $sel = $ui.GridPoints.SelectedItem
    if ($sel) { [void]$f.Points.Remove($sel) } else { $f.Points.RemoveAt($f.Points.Count - 1) }
    $script:Dirty = $true; Draw-Curve
})
$ui.GridPoints.Add_CellEditEnding({
    [void]$win.Dispatcher.BeginInvoke([System.Windows.Threading.DispatcherPriority]::Background, [Action]{ Draw-Curve })
})

# curve geometry
$script:XMin = 20; $script:XMax = 100; $script:XUnit = '°'; $CL = 40; $CR = 14; $CTp = 12; $CB = 26
function Update-AxisUi {
    $f = $script:SelFan
    if ($f -and $f.IsLoad) { $script:XMin = 0; $script:XMax = 100; $script:XUnit = '%'; $hdr = (T 'Load (%)') }
    else { $script:XMin = 20; $script:XMax = 100; $script:XUnit = '°'; $hdr = (T 'Temp. (°C)') }
    try { $ui.GridPoints.Columns[0].Header = $hdr } catch { }
}
function CX([double]$t) { $w = $ui.CurveCanvas.ActualWidth; return $CL + ($t - $script:XMin) / ($script:XMax - $script:XMin) * ($w - $CL - $CR) }
function CY([double]$p) { $h = $ui.CurveCanvas.ActualHeight; return $CTp + ($h - $CTp - $CB) * (1 - $p / 100.0) }
function InvX([double]$x) { $w = $ui.CurveCanvas.ActualWidth; return $script:XMin + ($x - $CL) / ($w - $CL - $CR) * ($script:XMax - $script:XMin) }
function InvY([double]$y) { $h = $ui.CurveCanvas.ActualHeight; return 100.0 * (1 - ($y - $CTp) / ($h - $CTp - $CB)) }

function Add-Shape($s) { [void]$ui.CurveCanvas.Children.Add($s) }
function New-Line([double]$x1, [double]$y1, [double]$x2, [double]$y2, $brush, [double]$th) {
    $l = New-Object System.Windows.Shapes.Line
    $l.X1 = $x1; $l.Y1 = $y1; $l.X2 = $x2; $l.Y2 = $y2; $l.Stroke = $brush; $l.StrokeThickness = $th
    return $l
}
function New-Label([string]$txt, [double]$x, [double]$y, $brush) {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $txt; $t.FontSize = 11; $t.Foreground = $brush
    [System.Windows.Controls.Canvas]::SetLeft($t, $x); [System.Windows.Controls.Canvas]::SetTop($t, $y)
    return $t
}

function Draw-Curve {
    $cv = $ui.CurveCanvas
    $f = $script:SelFan
    $w = $cv.ActualWidth; $h = $cv.ActualHeight
    if (-not $f -or $w -lt 80 -or $h -lt 60) { return }
    $cv.Children.Clear()
    $gridB = Brush '#22272C'; $lblB = Brush '#6C727A'
    for ($t = $script:XMin; $t -le $script:XMax; $t += 10) {
        $x = CX $t
        Add-Shape (New-Line $x (CY 100) $x (CY 0) $gridB 1)
        Add-Shape (New-Label "${t}$($script:XUnit)" ($x - 8) ((CY 0) + 5) $lblB)
    }
    for ($p = 0; $p -le 100; $p += 20) {
        $y = CY $p
        Add-Shape (New-Line (CX $script:XMin) $y (CX $script:XMax) $y $gridB 1)
        Add-Shape (New-Label "${p}%" 4 ($y - 8) $lblB)
    }
    $sorted = @($f.Points | Sort-Object Temp)
    if ($sorted.Count -eq 0) { return }
    $pc = New-Object System.Windows.Media.PointCollection
    $pc.Add((New-Object System.Windows.Point((CX $script:XMin), (CY $sorted[0].Pct))))
    foreach ($p in $sorted) { $pc.Add((New-Object System.Windows.Point((CX ([Math]::Max($script:XMin, [Math]::Min($script:XMax, $p.Temp)))), (CY $p.Pct)))) }
    $pc.Add((New-Object System.Windows.Point((CX $script:XMax), (CY $sorted[$sorted.Count - 1].Pct))))
    $fillPts = $pc.Clone()
    $fillPts.Add((New-Object System.Windows.Point((CX $script:XMax), (CY 0))))
    $fillPts.Add((New-Object System.Windows.Point((CX $script:XMin), (CY 0))))
    $poly = New-Object System.Windows.Shapes.Polygon
    $poly.Points = $fillPts
    $poly.Fill = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(36, 69, 211, 180))
    Add-Shape $poly
    $pl = New-Object System.Windows.Shapes.Polyline
    $pl.Points = $pc; $pl.Stroke = $Green; $pl.StrokeThickness = 2.2; $pl.StrokeLineJoin = 'Round'
    Add-Shape $pl

    # live marker
    if ($f.Mode -ne 0 -and -not [double]::IsNaN($f.InputTemp)) {
        $x = CX (Clamp $f.InputTemp $script:XMin $script:XMax)
        $ml = New-Line $x (CY 100) $x (CY 0) $Yellow 1
        $ml.StrokeDashArray = [System.Windows.Media.DoubleCollection]::Parse('4 3')
        Add-Shape $ml
        if (-not [double]::IsNaN($f.CurPct)) {
            $dot = New-Object System.Windows.Shapes.Ellipse; $dot.Width = 9; $dot.Height = 9; $dot.Fill = $Yellow
            [System.Windows.Controls.Canvas]::SetLeft($dot, $x - 4.5); [System.Windows.Controls.Canvas]::SetTop($dot, (CY $f.CurPct) - 4.5)
            Add-Shape $dot
        }
    }

    foreach ($p in $f.Points) {
        $e = New-Object System.Windows.Shapes.Ellipse
        $e.Width = 13; $e.Height = 13; $e.Fill = Brush '#0E1012'; $e.Stroke = $Green; $e.StrokeThickness = 2.5; $e.Cursor = 'SizeAll'
        $e.Tag = $p
        $e.ToolTip = "$($p.Temp) °C → $($p.Pct) %"
        [System.Windows.Controls.Canvas]::SetLeft($e, (CX ([Math]::Max($script:XMin, [Math]::Min($script:XMax, $p.Temp)))) - 6.5)
        [System.Windows.Controls.Canvas]::SetTop($e, (CY $p.Pct) - 6.5)
        $e.Add_MouseLeftButtonDown({ param($sender, $ev)
            if ($script:SelFan.Mode -ne 1) { return }
            $script:Drag = $sender.Tag
            [void]$ui.CurveCanvas.CaptureMouse()
            $ui.GridPoints.SelectedItem = $sender.Tag
            $ev.Handled = $true
        })
        $e.Add_MouseRightButtonDown({ param($sender, $ev)
            $ff = $script:SelFan
            if ($ff.Points.Count -gt 1 -and -not $script:Cfg.cfcGrid) { [void]$ff.Points.Remove($sender.Tag); $script:Dirty = $true; Draw-Curve }
            $ev.Handled = $true
        })
        Add-Shape $e
    }
}

$ui.CurveCanvas.Add_SizeChanged({ Draw-Curve })
$ui.CurveCanvas.Add_MouseMove({ param($sender, $ev)
    if (-not $script:Drag) { return }
    $pos = $ev.GetPosition($ui.CurveCanvas)
    if (-not $script:Cfg.cfcGrid) { $script:Drag.Temp = [int][Math]::Round((Clamp (InvX $pos.X) $script:XMin ([Math]::Min(105, $script:XMax + 5)))) }
    $script:Drag.Pct  = [int][Math]::Round((Clamp (InvY $pos.Y) 0 100))
    Draw-Curve
})
$ui.CurveCanvas.Add_MouseLeftButtonUp({
    if ($script:Drag) {
        $script:Drag = $null
        $ui.CurveCanvas.ReleaseMouseCapture()
        Sort-Points $script:SelFan
        $script:Dirty = $true
        Draw-Curve
    }
})
$ui.CurveCanvas.Add_MouseLeftButtonDown({ param($sender, $ev)
    if ($ev.ClickCount -ne 2 -or -not $script:SelFan -or $script:SelFan.Mode -ne 1 -or $script:Cfg.cfcGrid) { return }
    $pos = $ev.GetPosition($ui.CurveCanvas)
    $t = [int][Math]::Round((Clamp (InvX $pos.X) $script:XMin ([Math]::Min(105, $script:XMax + 5)))); $p = [int][Math]::Round((Clamp (InvY $pos.Y) 0 100))
    $script:SelFan.Points.Add((New-Object ClevoTune.CurvePoint($t, $p)))
    Sort-Points $script:SelFan
    $script:Dirty = $true
    Draw-Curve
})

function Update-FanUi {
    $hw = $script:Hw
    foreach ($k in @($script:FanItems.Keys)) {
        $f = $hw.Fans[$k - 1]
        $duty = Fmt $f.DutyPct '0'
        $script:FanItems[$k].Sub.Text = "$(Mode-Name $f.Mode) · $($f.Rpm) RPM · $duty %"
    }
    $f = $script:SelFan
    if ($f -and $hw.Ec) {
        if ($f.Mode -eq 0) { $ui.TxtFanLive.Text = ((T 'EC automatic · {0} RPM · {1} %') -f $f.Rpm, (Fmt $f.DutyPct '0')) }
        else {
            $src = T (@('CPU', 'GPU', 'max', 'CPU load', 'GPU load', 'max load')[$f.Source])
            $u = $(if ($f.IsLoad) { '%' } else { '°C' })
            $ui.TxtFanLive.Text = "$src $(Fmt $f.InputTemp '0') $u → $(Fmt $f.CurPct '0') % · $($f.Rpm) RPM"
            if ($hw.FailsafeActive) { $ui.TxtFanLive.Text += '  · ' + (T 'SAFETY') }
        }
    } else { $ui.TxtFanLive.Text = '' }
    # detect table edits
    if ($f) {
        $sig = ($f.Points | ForEach-Object { "$($_.Temp):$($_.Pct)" }) -join ','
        if ($sig -ne $script:PtSig) { if ($script:PtSig) { $script:Dirty = $true }; $script:PtSig = $sig }
    }
    if ($ui.Tabs.SelectedIndex -eq 1 -and -not $script:Drag) { Draw-Curve }
}

$ui.SlHyst.Add_ValueChanged({ $ui.ValHyst.Text = ('{0:0}' -f $ui.SlHyst.Value); if ($script:Loading) { return }; $script:Hw.Hysteresis = $ui.SlHyst.Value; $script:Cfg.hyst = [int]$ui.SlHyst.Value; $script:Dirty = $true })
$ui.SlDown.Add_ValueChanged({ $ui.ValDown.Text = ('{0:0} %/s' -f $ui.SlDown.Value); if ($script:Loading) { return }; $script:Hw.DownRate = $ui.SlDown.Value; $script:Cfg.down = [int]$ui.SlDown.Value; $script:Dirty = $true })
$ui.SlLoadSm.Add_ValueChanged({ $ui.ValLoadSm.Text = ('{0:0} s' -f $ui.SlLoadSm.Value); if ($script:Loading) { return }; $script:Hw.LoadSmoothSec = $ui.SlLoadSm.Value; $script:Cfg.loadSmooth = [int]$ui.SlLoadSm.Value; $script:Dirty = $true })
$ui.SlFail.Add_ValueChanged({ $ui.ValFail.Text = ('{0:0} °C' -f $ui.SlFail.Value); if ($script:Loading) { return }; $script:Hw.FailsafeTemp = $ui.SlFail.Value; $script:Cfg.failsafe = [int]$ui.SlFail.Value; $script:Dirty = $true })
function Set-AllAuto {
    foreach ($f in $script:Hw.Fans) { $f.Mode = 0 }
    $script:Hw.ReleaseAll()
    if ($script:SelFan) { Select-Fan $script:SelFan }
    $script:Dirty = $true
    Log (T 'All fans returned to the EC (auto)')
    Set-Status (T 'Fans in EC automatic mode') $Green
}
$ui.BtnAllAuto.Add_Click({ Set-AllAuto })


# ---------------------------------------------------------------- ClevoFanControl format (userfancurve.cfg)
# 20 lines: CPU fan % at 40,45,...,85 °C, then GPU fan % at the same temperatures
$CfcTemps = @(40, 45, 50, 55, 60, 65, 70, 75, 80, 85)

function Get-CfcDefaultPath {
    try {
        $probe = Join-Path $SelfDir '.write-test'
        [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force
        return (Join-Path $SelfDir 'userfancurve.cfg')
    } catch { return (Join-Path $DataDir 'userfancurve.cfg') }
}

function Set-GridPoints($f, $vals) {
    $f.Points.Clear()
    for ($i = 0; $i -lt 10; $i++) { $f.Points.Add((New-Object ClevoTune.CurvePoint([int]$CfcTemps[$i], [int]$vals[$i]))) }
    $f.EffTemp = [double]::NaN
}

function Get-GridValues($f) {
    $v = @()
    foreach ($t in $CfcTemps) {
        $x = [ClevoTune.Hw]::Interp($f.Points, [double]$t)
        if ([double]::IsNaN($x)) { $x = 100 }
        $v += [int][Math]::Round($x)
    }
    return , $v
}

function Test-OnGrid($f) {
    if ($f.Points.Count -ne 10) { return $false }
    $temps = @($f.Points | Sort-Object Temp | ForEach-Object { $_.Temp })
    for ($i = 0; $i -lt 10; $i++) { if ($temps[$i] -ne $CfcTemps[$i]) { return $false } }
    return $true
}

function Read-CfcFile([string]$path) {
    $nums = @()
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        $l = $line.Trim()
        if (-not $l) { continue }
        $n = 0
        if (-not [int]::TryParse($l, [ref]$n)) { throw ((T "invalid line: '{0}'") -f $l) }
        $nums += [Math]::Max(0, [Math]::Min(100, $n))
    }
    if ($nums.Count -lt 10) { throw ((T 'expected 20 values (10 CPU + 10 GPU), found {0}') -f $nums.Count) }
    return , $nums
}

function Import-Cfc([string]$path, [bool]$quiet) {
    $nums = Read-CfcFile $path
    $hw = $script:Hw
    if ($nums.Count -ge 20) {
        Set-GridPoints $hw.Fans[0] $nums[0..9]
        Set-GridPoints $hw.Fans[1] $nums[10..19]
        foreach ($i in 0, 1) { $hw.Fans[$i].Mode = 1; $hw.Fans[$i].Source = $i }
        Log ((T 'Curves imported from {0}: CPU {1} | GPU {2}') -f (Split-Path -Leaf $path), ($nums[0..9] -join ' '), ($nums[10..19] -join ' '))
    } else {
        $f = $script:SelFan; if (-not $f) { $f = $hw.Fans[0] }
        Set-GridPoints $f $nums[0..9]
        $f.Mode = 1
        Log ((T 'Curve imported from {0} to fan {1}: {2}') -f (Split-Path -Leaf $path), $f.Name, ($nums[0..9] -join ' '))
    }
    $script:Cfg.cfcGrid = $true
    $script:Dirty = $true
    if (-not $quiet) {
        Save-Config
        $ui.ChkCfcGrid.IsChecked = $true
        if ($script:SelFan) { Select-Fan $script:SelFan }
        Set-Status (T 'Curves imported and active (Curve mode)') $Green
    }
}

function Export-Cfc([string]$path) {
    $hw = $script:Hw
    $lines = @()
    $lossy = $false
    foreach ($i in 0, 1) {
        if (-not (Test-OnGrid $hw.Fans[$i])) { $lossy = $true }
        $lines += (Get-GridValues $hw.Fans[$i])
    }
    [IO.File]::WriteAllText($path, (($lines -join "`r`n") + "`r`n"), (New-Object Text.ASCIIEncoding))
    $msg = (T 'Curves exported to {0}') -f $path
    if ($lossy) { $msg += ' ' + (T '(points outside the 40–85 °C grid converted by interpolation)') }
    Log $msg
}

function Set-CfcGrid([bool]$on) {
    $script:Cfg.cfcGrid = $on
    if ($on) {
        foreach ($f in $script:Hw.Fans) { if (-not (Test-OnGrid $f)) { Set-GridPoints $f (Get-GridValues $f) } }
    }
    $script:Dirty = $true
    Update-GridLock
    Draw-Curve
}

function Update-GridLock {
    $g = [bool]$script:Cfg.cfcGrid
    try { $ui.GridPoints.Columns[0].IsReadOnly = $g } catch { }
    $ed = [bool]$script:Hw.Ec
    $ui.BtnAddPt.IsEnabled = $ed -and -not $g
    $ui.BtnDelPt.IsEnabled = $ed -and -not $g
    if ($g) { $ui.TxtCurveHelp.Text = T 'Fixed grid: 10 points at 40, 45 … 85 °C, as in ClevoFanControl. Edit only the % in the table or drag the points vertically. Below 40 °C the 1st value is used, above 85 °C the last.' }
    else { $ui.TxtCurveHelp.Text = T 'Drag the points on the chart or type the values in the table. Double-click the chart to add a point; right-click a point to remove it.' }
}

$ui.ChkCfcGrid.Add_Click({ Set-CfcGrid ([bool]$ui.ChkCfcGrid.IsChecked) })
$ui.BtnImportCfc.Add_Click({
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = (T 'ClevoFanControl curves (*.cfg)|*.cfg|All files (*.*)|*.*')
    $dlg.InitialDirectory = $SelfDir
    $dlg.FileName = 'userfancurve.cfg'
    if ($dlg.ShowDialog($win)) {
        try { Import-Cfc $dlg.FileName $false }
        catch { Log ((T 'Import failed: {0}') -f $_.Exception.Message); Set-Status (T 'Invalid curve file — see log') $Red }
    }
})
$ui.BtnExportCfc.Add_Click({
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = (T 'ClevoFanControl curves (*.cfg)|*.cfg|All files (*.*)|*.*')
    $dlg.InitialDirectory = $SelfDir
    $dlg.FileName = 'userfancurve.cfg'
    if ($dlg.ShowDialog($win)) {
        try { Export-Cfc $dlg.FileName; Set-Status ((T 'Exported: {0}') -f $dlg.FileName) $Green }
        catch { Log ((T 'Export failed: {0}') -f $_.Exception.Message); Set-Status (T 'Export failed — see log') $Red }
    }
})
$ui.BtnSaveCurves.Add_Click({
    try {
        Save-Config
        $p = Get-CfcDefaultPath
        Export-Cfc $p
        Set-Status ((T 'Curves saved (settings + {0})') -f (Split-Path -Leaf $p)) $Green
    } catch { Log ((T 'Save failed: {0}') -f $_.Exception.Message); Set-Status (T 'Save failed — see log') $Red }
})

# ---------------------------------------------------------------- overlay
$ovl = New-Object System.Windows.Window
$ovl.WindowStyle = 'None'; $ovl.AllowsTransparency = $true; $ovl.Background = [System.Windows.Media.Brushes]::Transparent
$ovl.Topmost = $true; $ovl.ShowInTaskbar = $false; $ovl.SizeToContent = 'WidthAndHeight'; $ovl.ShowActivated = $false
$ovl.ResizeMode = 'NoResize'; $ovl.Focusable = $false; $ovl.Title = 'ClevoTune overlay'
$ovlBorder = New-Object System.Windows.Controls.Border
$ovlBorder.CornerRadius = New-Object System.Windows.CornerRadius 6
$ovlBorder.Padding = Thick 10 6 10 6
$ovlText = New-Object System.Windows.Controls.TextBlock
$ovlText.FontFamily = New-Object System.Windows.Media.FontFamily 'Consolas'
$ovlText.Foreground = [System.Windows.Media.Brushes]::White
$fx = New-Object System.Windows.Media.Effects.DropShadowEffect; $fx.ShadowDepth = 1; $fx.BlurRadius = 3; $fx.Opacity = 0.9
$ovlText.Effect = $fx
$ovlBorder.Child = $ovlText
$ovl.Content = $ovlBorder
$ovl.Add_SourceInitialized({ [ClevoTune.Win]::ClickThrough((New-Object System.Windows.Interop.WindowInteropHelper($ovl)).Handle) })
function Position-Overlay {
    $wa = [System.Windows.SystemParameters]::WorkArea
    $m = 12
    $pos = [int]$script:Cfg.overlay.pos
    if ($pos -eq 0 -or $pos -eq 2) { $ovl.Left = $wa.Left + $m } else { $ovl.Left = $wa.Right - $ovl.ActualWidth - $m }
    if ($pos -lt 2) { $ovl.Top = $wa.Top + $m } else { $ovl.Top = $wa.Bottom - $ovl.ActualHeight - $m }
}
$ovl.Add_SizeChanged({ Position-Overlay })
function Apply-OverlayStyle {
    $o = $script:Cfg.overlay
    $ovlText.FontSize = [double]$o.font
    $a = [byte][Math]::Round(255 * [double]$o.opacity / 100)
    $ovlBorder.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb($a, 0, 0, 0))
    if ($o.enabled) { if (-not $ovl.IsVisible) { $ovl.Show() }; Position-Overlay } else { if ($ovl.IsVisible) { $ovl.Hide() } }
}
$script:OvlTick = 0
function Update-Overlay {
    $o = $script:Cfg.overlay
    if (-not $o.enabled) { return }
    $hw = $script:Hw
    $l = @()
    if ($o.cpu) { $l += ('CPU  {0,3}°C {1,4}% {2,4}W' -f (Fmt $hw.CpuTemp '0'), (Fmt $hw.CpuLoad '0'), (Fmt $hw.CpuPower '0')) }
    if ($o.gpu) { $l += ('GPU  {0,3}°C {1,4}% {2,4}W' -f (Fmt $hw.GpuTemp '0'), (Fmt $hw.GpuLoad '0'), (Fmt $hw.GpuPower '0')) }
    if ($o.clk) { $l += ('CLK  {0} / {1} MHz' -f (Fmt $hw.GpuClock '0'), (Fmt $hw.MemClock '0')) }
    if ($o.fan -and $hw.Ec) {
        $fs = @(); foreach ($f in $hw.Fans) { if ($f.Present) { $fs += ('{0} {1}%' -f $f.Name, (Fmt $f.DutyPct '0')) } }
        $l += 'FAN  ' + ($fs -join '  ')
    }
    if ($o.mem) { $l += ('MEM  RAM {0}/{1}  VRAM {2}/{3} GB' -f (Fmt $hw.RamUsed '0.0'), (Fmt $hw.RamTotal '0'), (Fmt $hw.VramUsed '0.0'), (Fmt $hw.VramTotal '0')) }
    $ovlText.Text = ($l -join "`n")
    $script:OvlTick++
    if ($script:OvlTick % 5 -eq 0) { $ovl.Topmost = $false; $ovl.Topmost = $true }
}
function Save-OverlayUi {
    if ($script:Loading) { return }
    $o = $script:Cfg.overlay
    $o.enabled = [bool]$ui.ChkOverlay.IsChecked
    $o.pos = [Math]::Max(0, $ui.CmbOvlPos.SelectedIndex)
    $o.font = [int]$ui.SlOvlFont.Value; $o.opacity = [int]$ui.SlOvlOp.Value
    $o.cpu = [bool]$ui.OvlCpu.IsChecked; $o.gpu = [bool]$ui.OvlGpu.IsChecked; $o.clk = [bool]$ui.OvlClk.IsChecked
    $o.fan = [bool]$ui.OvlFan.IsChecked; $o.mem = [bool]$ui.OvlMem.IsChecked
    $script:Dirty = $true
    Apply-OverlayStyle
    Update-Overlay
}
foreach ($n in 'ChkOverlay', 'OvlCpu', 'OvlGpu', 'OvlClk', 'OvlFan', 'OvlMem') { $ui[$n].Add_Click({ Save-OverlayUi }) }
$ui.CmbOvlPos.Add_SelectionChanged({ Save-OverlayUi })
$ui.SlOvlFont.Add_ValueChanged({ $ui.ValOvlFont.Text = ('{0:0}' -f $ui.SlOvlFont.Value); Save-OverlayUi })
$ui.SlOvlOp.Add_ValueChanged({ $ui.ValOvlOp.Text = ('{0:0} %' -f $ui.SlOvlOp.Value); Save-OverlayUi })

# ---------------------------------------------------------------- settings tab
$ui.BtnPawnSite.Add_Click({ Start-Process 'https://pawnio.eu' })
$ui.BtnLangFolder.Add_Click({
    $d = $script:LangDir; if (-not $d) { $d = Get-LangDir }
    Start-Process explorer.exe -ArgumentList "`"$d`""
})
$ui.BtnModFolder.Add_Click({
    if (-not (Test-Path -LiteralPath $ModDir)) { New-Item -ItemType Directory -Path $ModDir -Force | Out-Null }
    Start-Process explorer.exe -ArgumentList "`"$ModDir`""
})
function Reinit-Hw {
    try {
        $script:Timer.Stop()
        try { $script:Hw.Dispose() } catch { }
        $script:Hw = New-HwInstance
        $script:Hw.Tick(1.0)
        Update-Header
        Init-Tuning
        Build-FanList
        Log (T 'Sensors reinitialised')
        Set-Status (T 'Sensors reinitialised') $Green
    } catch { Log ((T 'Reinitialisation error: {0}') -f $_.Exception.Message) }
    finally { $script:Timer.Start() }
}
$ui.BtnReinit.Add_Click({ Reinit-Hw })
function Update-MVoltUi {
    if ($script:MVolt) {
        $v = Get-LocalMVoltVersion $script:MVolt
        $ui.TxtMVolt.Text = ((T 'mVolt+ {0} — {1}') -f $(if ($v) { $v } else { '?' }), $script:MVolt); $ui.TxtMVolt.Foreground = $Green
    }
    else { $ui.TxtMVolt.Text = (T 'mVolt+ not found. It is used for power limits and voltage offsets that the NVIDIA driver blocks on this GPU.'); $ui.TxtMVolt.Foreground = $Yellow }
}
$ui.BtnMVoltSite.Add_Click({ Start-Process 'https://github.com/b00nz/mVolt' })
$ui.BtnMVoltUpdate.Add_Click({
    $win.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        Set-Status (T 'Checking mVolt+ updates…') $Yellow
        Pump-Ui
        Update-MVolt $true
        $script:MVolt = Find-MVolt
        Save-Config
        Update-MVoltUi
        Init-Tuning
        Set-Status $ui.TxtMVolt.Text $Green
    } finally { $win.Cursor = $null }
})
$ui.BtnModules.Add_Click({
    $win.Cursor = [System.Windows.Input.Cursors]::Wait
    try {
        Set-Status (T 'Reinstalling PawnIO driver and modules…') $Yellow
        Pump-Ui
        $script:Timer.Stop()
        try { $script:Hw.ReleaseAll(); $script:Hw.Dispose() } catch { }
        Ensure-Dependencies $true
        Reinit-Hw
        if ($script:RebootNeeded) { Set-Status (T 'Installed — restart Windows to activate the driver') $Yellow }
    } catch {
        Log ((T 'Reinstall failed: {0}') -f $_.Exception.Message)
        Set-Status (T 'Reinstall failed — see log') $Red
    } finally { $win.Cursor = $null; $script:Timer.Start() }
})
$ui.ChkCloseTray.Add_Click({ $script:Cfg.closeToTray = [bool]$ui.ChkCloseTray.IsChecked; $script:Dirty = $true })
$ui.CmbInterval.Add_SelectionChanged({
    if ($script:Loading) { return }
    $ms = @(500, 1000, 2000)[[Math]::Max(0, $ui.CmbInterval.SelectedIndex)]
    $script:Cfg.interval = $ms; $script:Timer.Interval = [TimeSpan]::FromMilliseconds($ms); $script:Dirty = $true
})

function Refresh-Language {
    Apply-LangTargets
    # closed ComboBoxes cache the selected text: reselect so it shows the new language
    $script:Loading = $true
    foreach ($n in 'CmbFanMode', 'CmbFanSource', 'CmbPreset', 'CmbOvlPos', 'CmbInterval') {
        $cb = $ui[$n]; $i = $cb.SelectedIndex
        if ($i -ge 0) { $cb.SelectedIndex = -1; $cb.SelectedIndex = $i }
    }
    $ui.CmbLang.Items[0].Content = (T 'Automatic (system)')
    $i = $ui.CmbLang.SelectedIndex; $ui.CmbLang.SelectedIndex = -1; $ui.CmbLang.SelectedIndex = $i
    $script:Loading = $false
    foreach ($c in $script:Cards.Values) { $c.Title.Text = (T $c.TitleKey) }
    if ($ui.LogPanel.Visibility -eq 'Visible') { $ui.BtnLog.Content = (T 'Log ▾') } else { $ui.BtnLog.Content = (T 'Log ▴') }
    Update-Header
    Update-TuneTexts
    Update-Readback
    Update-MVoltUi
    Fill-Profiles
    Build-FanList
    Update-GridLock
    Update-AxisUi
    Draw-Curve
}
$ui.CmbLang.Add_SelectionChanged({
    if ($script:Loading -or $ui.CmbLang.SelectedIndex -lt 0) { return }
    $i = $ui.CmbLang.SelectedIndex
    if ($i -eq 0) { $script:Cfg.lang = 'auto' } else { $script:Cfg.lang = $script:Langs[$i - 1].Code }
    Set-Lang (Resolve-Lang ([string]$script:Cfg.lang))
    Save-Config
    Refresh-Language
    Log ((T 'Language changed: {0}') -f (Find-Lang $script:Lang).Name)
})

# ---------------------------------------------------------------- log toggle
$ui.BtnLog.Add_Click({
    if ($ui.LogPanel.Visibility -eq 'Visible') { $ui.LogPanel.Visibility = 'Collapsed'; $ui.BtnLog.Content = (T 'Log ▴') }
    else { $ui.LogPanel.Visibility = 'Visible'; $ui.BtnLog.Content = (T 'Log ▾'); $ui.TxtLog.ScrollToEnd() }
})

# ---------------------------------------------------------------- tray
$script:Tray = New-Object System.Windows.Forms.NotifyIcon
$script:Tray.Icon = $AppIcon
$script:Tray.Text = 'ClevoTune'
$script:Tray.Visible = $true
$script:TrayHinted = $false

function Show-Main {
    $win.Show()
    if ($win.WindowState -eq 'Minimized') { $win.WindowState = 'Normal' }
    [void]$win.Activate()
    $win.Topmost = $true; $win.Topmost = $false
}
function Build-TrayMenu {
    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    $i = $menu.Items.Add((T 'Open ClevoTune')); $i.Font = New-Object System.Drawing.Font($i.Font, [System.Drawing.FontStyle]::Bold)
    $i.Add_Click({ Show-Main })
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    foreach ($p in $script:Cfg.profiles) {
        $it = $menu.Items.Add(((T 'Apply profile: {0}') -f $p.name))
        $it.Tag = [string]$p.name
        $it.Add_Click({ param($sender, $e)
            $pp = Get-Profile ([string]$sender.Tag)
            if ($pp) { Load-ProfileToSliders $pp; Apply-Tuning ([int]$pp.power) ([int]$pp.core) ([int]$pp.mem) ([int]$pp.lock) ((T "Profile '{0}':") -f $pp.name) ([int]$pp.volt) }
        })
    }
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $a = $menu.Items.Add((T 'Fans → automatic (EC)')); $a.Add_Click({ Set-AllAuto })
    $sw = New-Object System.Windows.Forms.ToolStripMenuItem((T 'Start with Windows'))
    $sw.Checked = [bool]$script:Cfg.autoApply
    $sw.Add_Click({ Set-StartWithWindows (-not [bool]$script:Cfg.autoApply) })
    [void]$menu.Items.Add($sw)
    [void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $q = $menu.Items.Add((T 'Exit (returns fans to the EC)')); $q.Add_Click({ Exit-App })
    $old = $script:Tray.ContextMenuStrip
    $script:Tray.ContextMenuStrip = $menu
    if ($old) { $old.Dispose() }
}
$script:Tray.Add_MouseDoubleClick({ Show-Main })
$script:Tray.Add_MouseClick({ param($sender, $e) if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { Show-Main } })

# ---------------------------------------------------------------- window chrome
$ui.BtnMin.Add_Click({ $win.WindowState = 'Minimized' })
$ui.BtnMax.Add_Click({ if ($win.WindowState -eq 'Maximized') { $win.WindowState = 'Normal' } else { $win.WindowState = 'Maximized' } })
$win.Add_StateChanged({
    if ($win.WindowState -eq 'Maximized') { $win.Content.Margin = Thick 7 7 7 7 } else { $win.Content.Margin = Thick 0 0 0 0 }
})
$ui.BtnClose.Add_Click({ $win.Close() })
$script:Exiting = $false
$win.Add_Closing({ param($sender, $e)
    if ($script:Exiting) { return }
    $e.Cancel = $true
    if ($script:Cfg.closeToTray) {
        $win.Hide()
        if (-not $script:TrayHinted) {
            $script:TrayHinted = $true
            $script:Tray.ShowBalloonTip(3000, 'ClevoTune', (T 'Still running in the tray controlling the fans. Right-click → Exit to close.'), [System.Windows.Forms.ToolTipIcon]::Info)
        }
    } else { Exit-App }
})

function Exit-App {
    if ($script:Exiting) { return }
    $script:Exiting = $true
    try { $script:Timer.Stop() } catch { }
    try { $script:Hw.ReleaseAll(); Log (T 'Fans returned to the EC') } catch { }
    Save-Config
    try { $script:Tray.Visible = $false; $script:Tray.Dispose() } catch { }
    try { $ovl.Close() } catch { }
    try { $win.Close() } catch { }
    try { $script:Hw.Dispose() } catch { }
    $app.Shutdown()
}

$app.Add_SessionEnding({ try { $script:Hw.ReleaseAll() } catch { }; Save-Config })
$app.Add_DispatcherUnhandledException({ param($sender, $e) Log ((T 'Unexpected error: {0}') -f $e.Exception.Message); $e.Handled = $true })

# ---------------------------------------------------------------- timer loop
$script:SeenReinits = 0
$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds([int]$script:Cfg.interval)
$script:Watch = [System.Diagnostics.Stopwatch]::StartNew()
$script:Timer.Add_Tick({
    try {
        $dt = $script:Watch.Elapsed.TotalSeconds; $script:Watch.Restart()
        if ($dt -gt 10) { $dt = 1 }
        $script:Hw.Tick($dt)
        foreach ($m in $script:Hw.TakeMessages()) { Log $m }
        if ($script:Hw.NvmlReinits -ne $script:SeenReinits) { $script:SeenReinits = $script:Hw.NvmlReinits; if ($script:Hw.NvmlOk) { Update-Header; Init-Tuning } }
        Update-Cards
        if ($win.IsVisible) {
            Update-FanUi
            if ($ui.Tabs.SelectedIndex -eq 0 -and -not $ui.SlPower.IsEnabled) { Update-TuneTexts }
        }
        Update-Overlay
        $tip = 'ClevoTune · CPU ' + (Fmt $script:Hw.CpuTemp '0') + '°C · GPU ' + (Fmt $script:Hw.GpuTemp '0') + '°C'
        if ($tip.Length -gt 63) { $tip = $tip.Substring(0, 63) }
        $script:Tray.Text = $tip
        if ($script:ShowEvent.WaitOne(0)) { Show-Main }
        if ($script:Dirty -and ((Get-Date) - $script:LastSave).TotalSeconds -ge 2) { Save-Config }
    } catch { Log "Tick: $($_.Exception.Message)" }
})

# ---------------------------------------------------------------- startup
$ErrorActionPreference = 'Continue'
try { $script:Hw.Tick(1.0) } catch { }
Update-Header
Init-Tuning
Fill-Profiles

$script:Loading = $true
$ui.SlHyst.Value = [double]$script:Cfg.hyst; $ui.ValHyst.Text = ('{0:0}' -f $ui.SlHyst.Value)
$ui.SlDown.Value = [double]$script:Cfg.down; $ui.ValDown.Text = ('{0:0} %/s' -f $ui.SlDown.Value)
$ui.SlLoadSm.Value = [double]$script:Cfg.loadSmooth; $ui.ValLoadSm.Text = ('{0:0} s' -f $ui.SlLoadSm.Value)
$ui.SlFail.Value = [double]$script:Cfg.failsafe; $ui.ValFail.Text = ('{0:0} °C' -f $ui.SlFail.Value)
$ui.ChkCfcGrid.IsChecked = [bool]$script:Cfg.cfcGrid
$ui.CmbLang.Items.Clear()
[void]$ui.CmbLang.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = (T 'Automatic (system)') }))
foreach ($l in $script:Langs) { [void]$ui.CmbLang.Items.Add((New-Object System.Windows.Controls.ComboBoxItem -Property @{ Content = $l.Name })) }
$li = 0
if ([string]$script:Cfg.lang -and [string]$script:Cfg.lang -ne 'auto') {
    $fl = Find-Lang ([string]$script:Cfg.lang)
    if ($fl) { $li = $script:Langs.IndexOf($fl) + 1 }
}
$ui.CmbLang.SelectedIndex = [Math]::Max(0, $li)
$ui.BtnLog.Content = (T 'Log ▴')
$ui.ChkCloseTray.IsChecked = [bool]$script:Cfg.closeToTray
$ui.CmbInterval.SelectedIndex = [Math]::Max(0, [array]::IndexOf([int[]]@(500, 1000, 2000), [int]$script:Cfg.interval))
$o = $script:Cfg.overlay
$ui.ChkOverlay.IsChecked = [bool]$o.enabled; $ui.CmbOvlPos.SelectedIndex = [int]$o.pos
$ui.SlOvlFont.Value = [double]$o.font; $ui.ValOvlFont.Text = ('{0:0}' -f $ui.SlOvlFont.Value)
$ui.SlOvlOp.Value = [double]$o.opacity; $ui.ValOvlOp.Text = ('{0:0} %' -f $ui.SlOvlOp.Value)
$ui.OvlCpu.IsChecked = [bool]$o.cpu; $ui.OvlGpu.IsChecked = [bool]$o.gpu; $ui.OvlClk.IsChecked = [bool]$o.clk; $ui.OvlFan.IsChecked = [bool]$o.fan; $ui.OvlMem.IsChecked = [bool]$o.mem
$script:Loading = $false

$taskExists = Test-AutoStart
if ($script:Cfg.autoApply -and -not $taskExists) { $script:Cfg.autoApply = $false }
$ui.ChkAutoApply.IsChecked = [bool]$script:Cfg.autoApply
$ui.ChkStartup.IsChecked = [bool]$script:Cfg.autoApply
Build-TrayMenu
$ui.ChkApplyOnOpen.IsChecked = [bool]$script:Cfg.applyOnOpen
Update-AutoChip
if ($script:FirstRun -and $script:Hw.Ec) {
    foreach ($cand in (Join-Path $SelfDir 'userfancurve.cfg'), (Join-Path $DataDir 'userfancurve.cfg')) {
        if (Test-Path -LiteralPath $cand) {
            try { Import-Cfc $cand $true; $ui.ChkCfcGrid.IsChecked = $true; Save-Config } catch { Log ((T 'userfancurve.cfg ignored: {0}') -f $_.Exception.Message) }
            break
        }
    }
}
Build-FanList
Apply-OverlayStyle

Log "ClevoTune $AppVersion · $Model · $CpuName · $($script:Hw.GpuName) · driver $($script:Hw.Driver)"
Update-MVoltUi
if ($script:MVolt) { Log ((T 'mVolt+ found: {0}') -f $script:MVolt) }
if (-not $IsAdmin) { Log (T 'Warning: no administrator rights — PawnIO and GPU changes will fail.') }
if ($script:RebootNeeded -and -not $script:Hw.Ec) { Set-Status (T 'PawnIO installed — restart Windows to enable the fans and CPU sensors') $Yellow }
if (-not $script:Hw.Ec) { Log ((T 'Fans: {0}') -f (T $script:Hw.EcError)) }
if (-not $script:Hw.Msr) { Log ("CPU (MSR): " + (T $script:Hw.MsrError)) }
if (-not [ClevoTune.NvApi]::Ready) { Log "NVAPI: $([ClevoTune.NvApi]::LastError)" }
if ($script:Hw.Ec) {
    $names = @(); foreach ($f in $script:Hw.Fans) { if ($f.Present) { $names += "$($f.Index):$($f.Name)" } }
    Log ((T 'Fans detected: {0}') -f ($names -join ', '))
    if (Get-Process -Name 'ControlCenter*', 'CCenter*', 'HotKey*' -ErrorAction SilentlyContinue) { Log (T 'Warning: Clevo Control Center is running and may override the curves.') }
}

$startProfile = $null
if (($TrayStart -and $script:Cfg.autoApply) -or $script:Cfg.applyOnOpen) { $startProfile = Get-LastProfile }
if ($startProfile) {
    $p = $startProfile
    $script:Cfg.selectedProfile = [string]$p.name
    Fill-Profiles
    Load-ProfileToSliders $p
    Apply-Tuning ([int]$p.power) ([int]$p.core) ([int]$p.mem) ([int]$p.lock) ((T "On open: profile '{0}'") -f $p.name) ([int]$p.volt)
} elseif (-not ($script:RebootNeeded -and -not $script:Hw.Ec)) {
    Set-Status (T 'Ready') $Green
}

$script:Timer.Start()
if (-not $TrayStart) { $win.Show() }
[void]$app.Run()
