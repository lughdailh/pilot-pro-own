# Pilot Pro Own

Controlador USB natiu i de codi obert per al **XPPen Pilot Pro**, amb llicència [MIT](LICENSE).

Permet configurar les tres rodes, els vuit botons laterals, la creu inferior, el joystick i els botons del joystick i de la roda petita. En total, 28 senyals assignables, incloent-hi quatre diagonals independents.

- Pàgines amb títol, com Timeline i Browser, amb configuracions independents.
- Creació, duplicació i còpia completa de pàgines, també entre perfils.
- Selecció múltiple amb ⌘-clic o el menú del botó dret; còpia dels controls seleccionats a una altra pàgina o perfil.
- Connexió, perfil i identificació a l’esquerra; inspector de l’acció sempre a la dreta. Finestra flotant «Configuració» per a permisos, administració i exportació.
- Diagonals del joystick amb acció pròpia, inicialment buides: no activen les dues direccions rectes. S’identifiquen automàticament a partir dels eixos calibrats.
- Clic directe sobre «Sense drecera» o la drecera actual per gravar-la.
- Botons que executen dreceres, canvien de pàgina o combinen canvis de pàgina, tecles i pauses dins d’una seqüència.
- Etiquetes editables per a totes les accions; per defecte mostren la combinació gravada.
- Combinacions amb botons mantinguts premuts: una altra acció per a la mateixa roda, botó o direcció del joystick. Admet un o diversos modificadors; si fas servir la combinació, no s’envia també l’acció individual del modificador.
- Mode opcional «Roda seqüencial»: una llista compartida pels dos sentits, una drecera per pas, avançant o retrocedint segons el gir. Circular o amb aturada als extrems. Les accions separades es conserven en canviar de mode.
- Accions positiva (+) i negativa (−) de cada roda, amb el sentit de gir configurable per roda i pàgina.
- Exemple de macro: anar a Timeline → pausa de 50 ms → combinació de tecles.
- Zona morta del joystick en percentatge, ajust fi de 0,5 punts i vista en directe; desada per pàgina.
- Indicadors de controls identificats i pendents, configuració automàticament desada i exportació.

## Compilar

Destinació macOS 14 o posterior, amb Xcode o les eines de desenvolupament d’Apple i un SDK de macOS. Sense dependències externes.

```sh
git clone https://github.com/lughdailh/pilot-pro-own.git
cd pilot-pro-own
./scripts/build-app.sh
open "$HOME/Library/Caches/PilotProOwnBuild/Pilot Pro Own.app"
```

La signatura és ad hoc per defecte. Si tens certificat propi, pots indicar-lo amb `PILOT_CODESIGN_IDENTITY`. Per instal·lar-la, tanca l’app i copia **`~/Library/Caches/PilotProOwnBuild/Pilot Pro Own.app`** a **`/Applications/Pilot Pro Own.app`**.

Connecta el Pilot Pro per USB, identifica els controls, configura les dreceres i tanca el controlador oficial abans d’activar les dreceres pròpies. macOS pot requerir Accessibilitat i Monitoratge d’entrada.

La pàgina es tria al selector, a la barra de menús o amb un botó o pas de seqüència. Per moure també el focus de Final Cut, afegeix la drecera corresponent. El canvi de pàgina indicat dins d’una seqüència permet continuar-ne els passos; un canvi manual la cancel·la. Per copiar Browser a Timeline: selecciona Timeline, obre «Gestionar pàgines → Copiar tota la configuració des de…» i tria Browser com a origen.

Per crear una combinació: selecciona dos o més controls al mapa amb ⌘-clic → botó dret → «Crear combinació…». S’obre la pestanya «Combinacions» i l’editor per assignar-hi una drecera, un canvi de pàgina o una macro. La pestanya «Dreceres» edita l’acció normal. Si són dos botons, els pots prémer en qualsevol ordre. Si hi ha una roda o direcció del joystick, mantén els altres botons premuts mentre l’utilitzes. Les combinacions es desen per pàgina i també es copien amb el control. Si coincideix una combinació en girar una roda seqüencial, executa l’acció alternativa sense avançar-ne el recorregut.

Els cercles de l’anella exterior corresponen a «Roda gran exterior»; els interiors, a «Roda del joystick».

Per configurar una roda seqüencial: selecciona un cercle de la roda → «Mode de la roda» → «Roda seqüencial», afegeix les dreceres en ordre i desa. La primera rotació positiva comença pel primer pas; la negativa, per l’últim. Cada pas envia una sola drecera, sense reproduir tota la llista. La posició és independent per perfil, pàgina i roda, i es reinicia en activar/reconnectar, editar aquella pàgina o prémer «Reiniciar recorregut». El mode seqüencial fa servir tots els passos de la roda. En copiar un sentit d’una roda també es copia el seu mode seqüencial, compartit pels dos sentits.

La configuració es desa a `~/Library/Application Support/Pilot Pro Own/configuration.json`. La versió anterior migra conservant les assignacions i fent-ne una còpia de seguretat. Aquest repositori no inclou configuracions personals ni registres de diagnòstic.

## Verificació

```sh
./scripts/test.sh
```

Les proves del nucli funcionen sense dispositiu connectat. La lectura física USB s’ha provat en Apple Silicon; Bluetooth, vibració, Intel i totes les macros sobre aplicacions externes encara no estan validats. La resposta de velocitat al maquinari que configura XPPen encara no està reproduïda; actualment s’utilitza un filtre de passos per programari.

Consulta el [README principal](README.md) per a instruccions, limitacions, estructura del codi i contribucions.
