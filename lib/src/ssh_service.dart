import 'package:dartssh2/dartssh2.dart';
import 'ssh_key_generator.dart';

/// Exposes auditing-friendly core SSH connection, injection, and testing functions.
class EasyUnraidSshService {
  /// Test SSH Connection using either Password or Private Key.
  /// Returns 'success' if authentication succeeded, otherwise the error message.
  static Future<String> testConnection({
    required String host,
    required int port,
    required String username,
    String? password,
    String? privateKey,
  }) async {
    try {
      final client = SSHClient(
        await SSHSocket.connect(host, port, timeout: const Duration(seconds: 10)),
        username: username,
        onPasswordRequest: password != null && password.isNotEmpty ? () => password : null,
        identities: privateKey != null && privateKey.isNotEmpty ? SSHKeyPair.fromPem(privateKey) : null,
      );
      await client.authenticated;
      client.close();
      return 'success';
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Generates a local SSH Key pair, connects via Password to inject the public key
  /// to Unraid authorized_keys, and tests the key-based login.
  /// Returns a map with 'privateKey' and 'publicKey' if successful.
  static Future<Map<String, String>> generateAndInjectPublicKey({
    required String host,
    required int port,
    required String username,
    required String password,
    required String clientComment,
  }) async {
    // 1. Generate local SSH key pair asynchronously
    final keys = await SshKeyGenerator.generateSshKeyPair(comment: clientComment);
    final privateKey = keys['privateKey']!;
    final publicKey = keys['publicKey']!;

    // 2. Establish connection using current password
    final client = SSHClient(
      await SSHSocket.connect(host, port, timeout: const Duration(seconds: 10)),
      username: username,
      onPasswordRequest: () => password,
    );
    await client.authenticated;

    // 3. Inject public key into Unraid boot config
    final escapedPublicKey = publicKey.replaceAll("'", "'\\''");
    final commands = [
      "mkdir -p /boot/config/ssh/root",
      "touch /boot/config/ssh/root/authorized_keys",
      "(grep -v '$clientComment' /boot/config/ssh/root/authorized_keys > /boot/config/ssh/root/authorized_keys.tmp || true) && mv /boot/config/ssh/root/authorized_keys.tmp /boot/config/ssh/root/authorized_keys",
      "echo '$escapedPublicKey' >> /boot/config/ssh/root/authorized_keys",
      "chmod 600 /boot/config/ssh/root/authorized_keys"
    ];

    final session = await client.execute(commands.join(' && '));
    // Wait for command execution to complete and drain stdout/stderr
    await session.stdout.drain<void>();
    await session.stderr.drain<void>();
    client.close();

    // 4. Test connection using the newly generated private key
    final testClient = SSHClient(
      await SSHSocket.connect(host, port, timeout: const Duration(seconds: 5)),
      username: username,
      identities: SSHKeyPair.fromPem(privateKey),
    );
    await testClient.authenticated;
    testClient.close();

    return keys;
  }

  /// Connect using private key and remove the public key matching this device's comment
  /// from the Unraid server authorized_keys.
  static Future<String> revokePublicKey({
    required String host,
    required int port,
    required String username,
    required String privateKey,
    required String clientComment,
  }) async {
    try {
      final client = SSHClient(
        await SSHSocket.connect(host, port, timeout: const Duration(seconds: 8)),
        username: username,
        identities: SSHKeyPair.fromPem(privateKey),
      );
      await client.authenticated;

      // Remove only the line matching this device's unique comment
      final removeCommands = [
        "touch /boot/config/ssh/root/authorized_keys",
        "(grep -v '$clientComment' /boot/config/ssh/root/authorized_keys > /boot/config/ssh/root/authorized_keys.tmp || true) && mv /boot/config/ssh/root/authorized_keys.tmp /boot/config/ssh/root/authorized_keys",
        "chmod 600 /boot/config/ssh/root/authorized_keys",
      ];

      final session = await client.execute(removeCommands.join(' && '));
      await session.stdout.drain<void>();
      await session.stderr.drain<void>();
      client.close();

      return 'success';
    } catch (e) {
      return 'failed: $e';
    }
  }
}
