# wdm-policemgmt

## 🚔 **Police Management System**

A comprehensive administrative tool for QBOX servers that allows police department leaders to manage their force through a modern, real-time interface. The system provides complete officer management including hiring, rank assignments, callsign management, and officer termination - all synchronized live across the server.

**Key Features:**
- **Officer Management**: View all department officers with real-time online/offline status
- **Callsign Assignment**: Assign and manage officer callsigns with validation and uniqueness checks
- **Rank Management**: Promote/demote officers with proper permission controls
- **Officer Recruitment**: Hire new officers using server IDs with instant job assignment
- **Real-time Sync**: All changes update immediately across the server
- **Multi-Department Support**: Works with LSPD, BCSO, and SASP departments
- **Secure Permissions**: Rank-based access control (Sergeant+ for management, Lieutenant+ for termination)
- **Modern UI**: Clean black/dark blue interface with smooth animations

**How It Works:**
The system uses a client-side NUI interface connected to server-side database management. When administrators open the panel, it automatically syncs with the database to display current officers. All changes are stored in dedicated database tables and immediately reflected in player data through QBOX integration. The system includes automatic officer synchronization, ensuring existing police officers are properly tracked without manual setup.

Perfect for maintaining professional police operations with complete administrative oversight and real-time department management.
