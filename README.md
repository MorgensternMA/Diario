# Diario

Agenda y diario personal en Flutter: calendario, secciones de pendientes personalizadas, listas, seguimiento del ciclo menstrual, estado de ánimo diario y hábitos.

**Todo se guarda en el celular** (SQLite local): no usa servidor, no necesita conexión y no pide permiso de internet. Para no perder nada, desde la app se puede hacer una copia de seguridad manual a un archivo y restaurarla.

## Qué tiene

| Pestaña | Para qué |
|---|---|
| **Hoy** | Cómo te sentís (ánimo 1–5 + emociones), diario libre (se guarda solo), eventos del día, pendientes de listas que vencen ese día, hábitos y flujo menstrual. Deslizá a los costados para cambiar de día. |
| **Calendario** | Vista del mes con eventos (con el color de su sección), días de período, período estimado, ventana fértil, ovulación y ánimo. Tocá un día para ver el resumen, o mantené presionado para abrirlo. |
| **Agenda** | Próximos eventos filtrados por sección. Las secciones (Exámenes, Turnos médicos, Social, Trabajo…) se crean, editan y borran con color e ícono propios. |
| **Listas** | To-do, Supermercado y Compras importantes ya vienen creadas, y podés agregar las que quieras. Los ítems pueden tener cantidad, nota y una fecha límite (aparecen ese día en "Hoy"). |
| **Ciclo** | Día del ciclo, cuánto falta (o el atraso), promedios, próximos 3 períodos con ventana fértil, e historial. |

En **Hoy → ⋮** están:

- **Hábitos y trackers:** pueden ser de cuatro tipos: sí/no, contador (con meta), número (horas de sueño, peso…) y escala de 1 a 5. Cada uno tiene un historial de 12 semanas con racha y promedio.
- **Copia de seguridad:** "Hacer copia" guarda un `.json` donde elijas (Drive, Descargas, etc.). "Restaurar" reemplaza todos los datos por los de una copia.

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

Son estimaciones: no sirven como método anticonceptivo.

## Estructura

```
app/lib/
  main.dart            navegación y tema
  models.dart          clases de datos
  common.dart          fechas, colores, íconos y widgets compartidos
  data/store.dart      base SQLite, consultas y backup/restore
  data/cycles.dart     cálculo del ciclo y predicciones
  screens/             una pantalla por archivo
```

La carpeta `backend/` tiene la primera versión con servidor en Go. La app ya no la usa.
