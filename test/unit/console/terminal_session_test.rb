# frozen_string_literal: true

require "test_helper"

class ConsoleTerminalSessionTest < Minitest::Test
  # ---------------------------
  # Protocol encoding
  # ---------------------------

  def test_encode_input_wraps_data_in_xtermjs_format
    session = build_session
    encoded = session.send(:encode_input, "hello")
    assert_equal "0:5:hello", encoded
  end

  def test_encode_input_handles_multibyte_characters
    session = build_session
    encoded = session.send(:encode_input, "\xC3\xA9") # é = 2 bytes
    assert_equal "0:2:\xC3\xA9", encoded
  end

  def test_encode_input_handles_empty_string
    session = build_session
    encoded = session.send(:encode_input, "")
    assert_equal "0:0:", encoded
  end

  def test_encode_resize_formats_correctly
    session = build_session
    encoded = session.send(:encode_resize, 80, 24)
    assert_equal "1:80:24:", encoded
  end

  def test_encode_ping_returns_single_digit
    session = build_session
    encoded = session.send(:encode_ping)
    assert_equal "2", encoded
  end

  # ---------------------------
  # Disconnect key detection
  # ---------------------------

  def test_disconnect_key_detects_ctrl_close_bracket
    session = build_session
    assert session.send(:disconnect_key?, "\x1d") # Ctrl+]
  end

  def test_disconnect_key_rejects_normal_input
    session = build_session
    refute session.send(:disconnect_key?, "a")
    refute session.send(:disconnect_key?, "\n")
    refute session.send(:disconnect_key?, "\x03") # Ctrl+C
  end

  # ---------------------------
  # Handshake message
  # ---------------------------

  def test_handshake_message_format
    session = build_session(user: "root@pam", ticket: "PVEVNC:abc123")
    msg = session.send(:handshake_message)
    assert_equal "root@pam:PVEVNC:abc123\n", msg
  end

  private

  def build_session(user: "root@pam", ticket: "PVEVNC:test")
    Pvectl::Console::TerminalSession.new(
      url: "wss://pve1.example.com:8006/api2/json/nodes/pve1/qemu/100/vncwebsocket?port=5900&vncticket=PVEVNC:test",
      cookie: "PVEAuthCookie=PVE:root@pam:abc",
      user: user,
      ticket: ticket,
      verify_ssl: true
    )
  end
end
