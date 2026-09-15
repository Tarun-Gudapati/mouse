namespace IdleKeepAlive;

public sealed class MainForm : Form
{
    private const int IntervalSeconds = 5;

    private readonly Label _statusLabel;
    private readonly Label _idleLabel;
    private readonly Button _onButton;
    private readonly Button _offButton;
    private readonly System.Windows.Forms.Timer _nudgeTimer;
    private readonly System.Windows.Forms.Timer _uiTimer;
    private bool _isOn;

    public MainForm()
    {
        Text = "Idle Keep-Alive";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(320, 188);
        BackColor = Color.White;
        Font = new Font("Segoe UI", 10);

        var title = new Label
        {
            Text = "Keep Windows idle time at 0",
            Location = new Point(20, 16),
            Size = new Size(280, 24),
            Font = new Font("Segoe UI", 11, FontStyle.Bold)
        };

        var statusCaption = new Label
        {
            Text = "Status",
            Location = new Point(20, 52),
            Size = new Size(80, 22),
            ForeColor = Color.DimGray
        };

        _statusLabel = new Label
        {
            Text = "OFF",
            Location = new Point(100, 50),
            Size = new Size(200, 24),
            Font = new Font("Segoe UI", 12, FontStyle.Bold),
            ForeColor = Color.Firebrick
        };

        var idleCaption = new Label
        {
            Text = "Idle",
            Location = new Point(20, 82),
            Size = new Size(80, 22),
            ForeColor = Color.DimGray
        };

        _idleLabel = new Label
        {
            Text = "0 ms",
            Location = new Point(100, 80),
            Size = new Size(200, 24)
        };

        var hint = new Label
        {
            Text = $"Nudges the mouse 1px every {IntervalSeconds} seconds while ON.",
            Location = new Point(20, 110),
            Size = new Size(280, 20),
            ForeColor = Color.Gray,
            Font = new Font("Segoe UI", 8)
        };

        _onButton = new Button
        {
            Text = "ON",
            Location = new Point(20, 140),
            Size = new Size(135, 34),
            BackColor = Color.ForestGreen,
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat
        };
        _onButton.FlatAppearance.BorderSize = 0;
        _onButton.Click += (_, _) => TurnOn();

        _offButton = new Button
        {
            Text = "OFF",
            Location = new Point(165, 140),
            Size = new Size(135, 34),
            BackColor = Color.Firebrick,
            ForeColor = Color.White,
            FlatStyle = FlatStyle.Flat,
            Enabled = false
        };
        _offButton.FlatAppearance.BorderSize = 0;
        _offButton.Click += (_, _) => TurnOff();

        _nudgeTimer = new System.Windows.Forms.Timer { Interval = IntervalSeconds * 1000 };
        _nudgeTimer.Tick += (_, _) =>
        {
            if (_isOn)
            {
                Native.NudgeMouse();
            }
        };

        _uiTimer = new System.Windows.Forms.Timer { Interval = 250 };
        _uiTimer.Tick += (_, _) => _idleLabel.Text = $"{Native.GetIdleMs():N0} ms";
        _uiTimer.Start();

        Controls.AddRange([title, statusCaption, _statusLabel, idleCaption, _idleLabel, hint, _onButton, _offButton]);
        FormClosing += (_, _) =>
        {
            TurnOff();
            _uiTimer.Stop();
            _nudgeTimer.Stop();
        };
    }

    private void TurnOn()
    {
        _isOn = true;
        Native.SetThreadExecutionState(
            Native.EsContinuous | Native.EsSystemRequired | Native.EsDisplayRequired);
        Native.NudgeMouse();
        _nudgeTimer.Start();
        _statusLabel.Text = "ON";
        _statusLabel.ForeColor = Color.ForestGreen;
        _onButton.Enabled = false;
        _offButton.Enabled = true;
    }

    private void TurnOff()
    {
        _isOn = false;
        _nudgeTimer.Stop();
        Native.SetThreadExecutionState(Native.EsContinuous);
        _statusLabel.Text = "OFF";
        _statusLabel.ForeColor = Color.Firebrick;
        _onButton.Enabled = true;
        _offButton.Enabled = false;
    }
}
