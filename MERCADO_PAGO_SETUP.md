# Configuración de Integración con Mercado Pago

Esta guía te ayudará a configurar la integración con Mercado Pago para sincronizar automáticamente tus pagos con la aplicación.

## ¿Qué hace esta integración?

La integración con Mercado Pago te permite:
- ✅ **Sincronizar pagos automáticamente** - Los pagos que realices con Mercado Pago se agregan automáticamente como transacciones
- ✅ **Categorización inteligente** - Los pagos se categorizan automáticamente según su descripción
- ✅ **Historial completo** - Accede a todos tus pagos de Mercado Pago desde la app
- ✅ **Sin duplicados** - El sistema evita agregar el mismo pago dos veces

## Requisitos previos

1. Una cuenta de Mercado Pago activa
2. Acceso al panel de desarrolladores de Mercado Pago
3. Una aplicación creada en Mercado Pago

## Paso 1: Crear una aplicación en Mercado Pago

1. Ve a [https://www.mercadopago.com.ar/developers](https://www.mercadopago.com.ar/developers)
2. Inicia sesión con tu cuenta de Mercado Pago
3. Ve a "Tus integraciones" > "Crear aplicación"
4. Completa los datos de tu aplicación:
   - **Nombre**: "Posición App" (o el que prefieras)
   - **Descripción**: "Gestión de finanzas personales"
   - **Tipo**: Aplicación
5. Una vez creada, anota los siguientes datos:
   - `Client ID`
   - `Client Secret`

## Paso 2: Configurar la URL de redirección

1. En el panel de tu aplicación en Mercado Pago
2. Ve a "Configuración" > "OAuth"
3. Agrega la siguiente URL de redirección:
   ```
   https://misnumeros.app/mp-callback
   ```
4. Guarda los cambios

**Nota**: Si quieres usar una URL diferente, asegúrate de actualizar también el código en `lib/services/mercado_pago_service.dart`

## Paso 3: Configurar las credenciales en la app

1. Abre el archivo: `lib/services/mercado_pago_service.dart`
2. Busca las siguientes líneas (alrededor de la línea 35):
   ```dart
   MercadoPagoService({
     this.clientId = 'TU_CLIENT_ID',
     this.clientSecret = 'TU_CLIENT_SECRET',
     this.redirectUri = 'https://misnumeros.app/mp-callback',
   });
   ```
3. Reemplaza `'TU_CLIENT_ID'` con tu Client ID de Mercado Pago
4. Reemplaza `'TU_CLIENT_SECRET'` con tu Client Secret de Mercado Pago

**Ejemplo:**
```dart
MercadoPagoService({
  this.clientId = 'APP_USR-1234567890-123456-abcdef123456-123456',
  this.clientSecret = 'abcdef1234567890abcdef1234567890',
  this.redirectUri = 'https://misnumeros.app/mp-callback',
});
```

## Paso 4: Conectar tu cuenta en la app

1. Abre la aplicación
2. Ve a **Configuración** (Settings)
3. En la sección **Integraciones**, toca en **Mercado Pago**
4. Toca el botón **Conectar con Mercado Pago**
5. Serás redirigido a la página de autorización de Mercado Pago
6. Inicia sesión con tu cuenta de Mercado Pago
7. Autoriza el acceso a tu información
8. Serás redirigido automáticamente a la app

¡Listo! Tu cuenta de Mercado Pago está conectada.

## Cómo usar la sincronización

### Sincronización manual

1. Ve a **Configuración** > **Mercado Pago**
2. Toca el botón **Sincronizar Pagos**
3. La app descargará todos los pagos del día actual
4. Los nuevos pagos aparecerán como transacciones en tu cuenta

### Configurar la cuenta de destino

Por defecto, los pagos se agregarán a:
1. Una cuenta que contenga "Mercado Pago" o "MercadoPago" en su nombre, o
2. Tu primera cuenta digital, o
3. Tu primera cuenta disponible

**Recomendación**: Crea una cuenta digital llamada "Mercado Pago" para mantener tus pagos organizados.

### Identificación de pagos sincronizados

Todos los pagos sincronizados incluyen en la descripción el código:
```
(MP#[ID_DEL_PAGO])
```

Esto permite:
- Identificar fácilmente qué transacciones vienen de Mercado Pago
- Evitar duplicados en sincronizaciones futuras
- Rastrear el pago original en Mercado Pago si es necesario

## Categorización automática

Los pagos se categorizan automáticamente según palabras clave:

| Palabras clave | Categoría |
|----------------|-----------|
| uber, taxi | Transporte |
| restaurant, comida, food | Alimentación |
| shop, store, tienda | Compras |
| (tarjeta de crédito) | Tarjeta de Crédito |
| (tarjeta de débito) | Tarjeta de Débito |
| (otros) | Mercado Pago |

Puedes editar la categoría manualmente después de la sincronización.

## Solución de problemas

### "Por favor configura las credenciales de Mercado Pago primero"
- Verifica que hayas reemplazado `TU_CLIENT_ID` y `TU_CLIENT_SECRET` en el código
- Asegúrate de que los valores no estén entre comillas dobles extra

### "Error al obtener el token de acceso"
- Verifica que las credenciales sean correctas
- Asegúrate de que la URL de redirección coincida en Mercado Pago y en el código
- Verifica que la aplicación esté activa en el panel de Mercado Pago

### "No hay nuevos pagos para sincronizar"
- La sincronización solo trae pagos del día actual
- Verifica que tengas pagos aprobados en Mercado Pago
- Los pagos pendientes o cancelados no se sincronizan

### La autorización no funciona
- Asegúrate de tener conexión a internet
- Verifica que el WebView esté habilitado (paquete `webview_flutter` instalado)
- Intenta cerrar sesión en Mercado Pago desde el navegador y vuelve a intentar

## Seguridad

### Almacenamiento de tokens
Los tokens de acceso se almacenan de forma segura usando `flutter_secure_storage`:
- **Android**: Usa EncryptedSharedPreferences
- **iOS**: Usa Keychain
- **Web/Desktop**: Usa almacenamiento local con encriptación

### Buenas prácticas
1. ✅ Nunca compartas tus credenciales (Client ID/Secret)
2. ✅ No subas el archivo con credenciales a repositorios públicos
3. ✅ Usa credenciales de prueba durante el desarrollo
4. ✅ Cambia a credenciales de producción solo cuando esté listo
5. ✅ Revoca el acceso desde Mercado Pago si ya no usas la app

## API de Mercado Pago utilizada

La integración usa los siguientes endpoints de Mercado Pago:

- **OAuth**: `https://auth.mercadopago.com.ar/authorization`
- **Token Exchange**: `POST /oauth/token`
- **Refresh Token**: `POST /oauth/token` (grant_type: refresh_token)
- **Search Payments**: `GET /v1/payments/search`
- **User Info**: `GET /users/me`

## Limitaciones actuales

- ⚠️ Solo sincroniza pagos del día actual
- ⚠️ No sincroniza pagos recurrentes automáticamente (se sincroniza cada pago individualmente)
- ⚠️ No soporta múltiples cuentas de Mercado Pago simultáneamente
- ⚠️ Solo pagos con estado "approved" se sincronizan

## Próximas mejoras

Mejoras planificadas para futuras versiones:
- 🔜 Sincronización automática en segundo plano
- 🔜 Sincronización de rangos de fechas personalizados
- 🔜 Notificaciones de nuevos pagos
- 🔜 Soporte para webhooks de Mercado Pago
- 🔜 Configuración de categorización personalizada

## Soporte

Si tienes problemas con la integración:
1. Revisa la sección de solución de problemas arriba
2. Verifica los logs de la aplicación
3. Consulta la [documentación oficial de Mercado Pago](https://www.mercadopago.com.ar/developers/es/docs)

---

**Última actualización**: Diciembre 2024
**Versión de la app**: 1.0.0
