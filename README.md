# Diario

Tu **bolso virtual**: agenda, listas, diario, ánimo, comidas, remedios, hábitos y ciclo, todo en un solo lugar. Hecha en Flutter.

**Todo se guarda en el celular** (SQLite local): no usa servidor, no necesita conexión y no pide permiso de internet. Para no perder nada, desde la app se puede hacer una copia de seguridad manual a un archivo y restaurarla.

## Qué tiene

La app tiene tres pestañas:

- **Hoy**: tu día. Arriba hay una tira con la semana para cambiar de día (también se puede deslizar). Incluye:
  - **¿Cómo estás?**: ánimo, energía, ganas y hambre (de 1 a 5), emociones y un diario libre que se guarda solo.
  - Agenda del día y pendientes de listas que vencen ese día.
  - Comidas con las calorías del día, remedios tomados y hábitos.
  - Una fila compacta del ciclo para registrar el flujo y los síntomas.
  - Si tus ciclos anteriores muestran un patrón para ese día del ciclo, un aviso (por ejemplo, "podrías sentir menos energía").
  - El botón **+** agrega rápido un evento, una comida, un remedio o algo a una lista.
- **Calendario**: el mes con eventos (con el color de su sección), ánimo, período, período estimado, ventana fértil y ovulación. Abajo, **Tu mes**: gráfico de líneas con energía, ganas, ánimo y hambre del mes; lo anotado en línea llena y los días que vienen como proyección (más clara). Tocar el gráfico selecciona el día.
- **Mi bolso**: todos los compartimentos, cada uno con un resumen:
  - **Agenda**: próximos eventos por sección. Las secciones (Exámenes, Turnos médicos, Social…) se crean con color e ícono propios.
  - **Listas**: Pendientes, Supermercado, Compras importantes y las que agregues. Los ítems pueden tener cantidad, nota y fecha límite.
  - **Comidas**: calorías y proteína por comida (desayuno, almuerzo, merienda, cena, snacks), con metas diarias opcionales de las dos. Al anotar, podés buscar en una base de alimentos comunes (`assets/foods.db`, ver abajo) y poner los gramos para que calcule calorías y proteína, o repetir comidas frecuentes con un toque.
  - **Hábitos**: trackers de sí/no, contador, número o escala del 1 al 5, con historial de 12 semanas.
  - **Mi diario**: todos tus días escritos.
  - **Ciclo**: estado, gráfico "Cómo vas a estar" con energía, ganas, ánimo y hambre proyectados para las próximas 5 semanas (se arrastra para ver cada día), tus patrones (lo que se repite en tus ciclos), lo que viene en las próximas semanas, próximos períodos e historial.
  - **Personalizar Hoy**: ocultar las secciones que no uses, incluido el ciclo (eso también oculta sus marcas en el calendario).
  - **Copia de seguridad**: "Hacer copia" guarda un `.json` donde elijas; "Restaurar" reemplaza todo por una copia.

## Generar e instalar el APK

```sh
cd app
flutter pub get
flutter build apk --release --split-per-abi
```

Para casi cualquier celular actual sirve `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. Pasalo al celu e instalalo (Android va a pedir permitir "instalar apps de origen desconocido").

Para probar durante el desarrollo: `flutter run`. Tests: `flutter test`.

## Cómo se calcula el ciclo

- Los días con sangrado separados por hasta 2 días sin registro cuentan como el mismo período. El manchado al principio o al final no cuenta como inicio, y un manchado suelto no cuenta como período.
- La duración del ciclo es el promedio de los últimos 6 ciclos (se descartan los de menos de 15 o más de 60 días, que suelen ser errores de carga). Un período en curso no entra en el promedio de duración. Hasta tener datos se usan 28 días de ciclo y 5 de período.
- La ovulación se estima 14 días antes del próximo período, y la ventana fértil va de 5 días antes a 1 día después.

### Patrones del ciclo

No es IA: es un cálculo estadístico simple que corre en el celular, con tus propios registros.

Cada día registrado (energía, ganas, ánimo, hambre y remedios) se ubica en su día del ciclo. Para cada día del ciclo se promedian los valores de ese día y de los dos vecinos. Un día "se destaca" si su promedio está al menos 0,6 por debajo o por encima de tu promedio general ("menos energía", "más ganas"…), y solo si eso pasa en **al menos 2 ciclos distintos**. Los remedios cuentan cuando los tomaste ese día del ciclo en 2 o más ciclos. Esos días se proyectan sobre las próximas 5 semanas repitiendo tu ciclo promedio. Con cada ciclo nuevo hay más datos, y los patrones se vuelven más precisos.

Son estimaciones: no sirven como método anticonceptivo.

## Base de alimentos

`app/assets/foods.db` es una SQLite de solo lectura que viene dentro de la app (no usa internet). Tiene unos 130 alimentos comunes con nombre en español y calorías y proteína cada 100 g, tomados de **USDA FoodData Central – SR Legacy** (Departamento de Agricultura de EE.UU., dominio público).

Para regenerarla o sumar alimentos:

1. Bajá a mano el archivo "SR Legacy" en formato JSON desde el sitio oficial, https://fdc.nal.usda.gov/download-datasets, y descomprimilo.
2. Agregá filas a `app/tool/generic_foods.tsv` (nombre en español, descripción exacta de USDA, porción en gramos y, opcionalmente, cómo se lee la porción).
3. Desde `app/`, corré `python3 -I tool/build_food_db.py <archivo.json>`. El script solo lee archivos locales.
4. Si cambian los datos, subí `_version` en `lib/data/food_db.dart` para que el celular reemplace su copia.

## Estructura

```
app/lib/
  main.dart            navegación (Hoy, Calendario, Mi bolso)
  theme.dart           paleta, tipografías (Fraunces + Nunito) y tema
  models.dart          clases de datos
  common.dart          fechas, colores, íconos y widgets compartidos
  data/store.dart      base SQLite, migraciones, consultas y backup/restore
  data/cycles.dart     cálculo del ciclo y predicciones
  data/insights.dart   patrones de energía/ganas/hambre/remedios por día del ciclo
  data/food_db.dart    búsqueda en la base de alimentos (assets/foods.db)
  screens/             una pantalla por archivo
app/tool/render_icon_test.dart   dibuja el ícono (luego: dart run flutter_launcher_icons)
app/tool/build_food_db.py        arma assets/foods.db desde el archivo de USDA
```

La carpeta `backend/` tiene la primera versión con servidor en Go. La app ya no la usa.
