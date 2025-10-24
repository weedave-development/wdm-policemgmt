// Police Management System - NUI JavaScript
class PoliceManagement {
    constructor() {
        this.currentOfficers = [];
        this.currentOfficer = null;
        this.playerData = null;
        this.config = null;
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.setupNUIListeners();
    }

    setupEventListeners() {
        // Close button
        document.getElementById('closeBtn').addEventListener('click', () => {
            this.closeManagement();
        });

        // Tab navigation
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.switchTab(e.target.dataset.tab);
            });
        });

        // Search functionality
        document.getElementById('searchOfficers').addEventListener('input', (e) => {
            this.filterOfficers(e.target.value);
        });

        // Add officer form
        document.getElementById('addOfficerForm').addEventListener('submit', (e) => {
            e.preventDefault();
            this.addOfficer();
        });

        // Modal close buttons
        document.getElementById('closeModal').addEventListener('click', () => {
            this.closeModal();
        });

        // Officer actions
        document.getElementById('updateCallsign').addEventListener('click', () => {
            this.updateCallsign();
        });

        document.getElementById('updateRank').addEventListener('click', () => {
            this.updateRank();
        });

        document.getElementById('terminateOfficer').addEventListener('click', () => {
            this.showConfirmDialog(
                'Terminate Officer',
                'Are you sure you want to terminate this officer? This action cannot be undone.',
                () => this.terminateOfficer()
            );
        });

        // Confirmation modal
        document.getElementById('confirmYes').addEventListener('click', () => {
            this.confirmAction();
        });

        document.getElementById('confirmNo').addEventListener('click', () => {
            this.closeConfirmModal();
        });

        // Cancel add officer
        document.getElementById('cancelAdd').addEventListener('click', () => {
            this.switchTab('officers');
        });

        // Close modals on outside click
        document.addEventListener('click', (e) => {
            if (e.target.classList.contains('modal')) {
                this.closeModal();
                this.closeConfirmModal();
            }
        });
    }

    setupNUIListeners() {
        window.addEventListener('message', (event) => {
            const data = event.data;
            
            switch (data.action) {
                case 'openManagement':
                    this.openManagement(data.playerData, data.config);
                    break;
                case 'closeManagement':
                    this.closeManagement();
                    break;
                case 'updateOfficers':
                    this.updateOfficersList(data.officers);
                    break;
                case 'updateOfficerDetails':
                    this.updateOfficerDetails(data.officerInfo, data.callsignHistory);
                    break;
            }
        });
    }

    openManagement(playerData, config) {
        this.playerData = playerData;
        this.config = config;
        
        document.getElementById('app').classList.remove('hidden');
        document.getElementById('userName').textContent = playerData.name;
        document.getElementById('userRank').textContent = playerData.gradeName;
        
        this.switchTab('officers');
        this.requestOfficers();
    }

    closeManagement() {
        document.getElementById('app').classList.add('hidden');
        this.sendNUICallback('closeManagement', {});
    }

    switchTab(tabName) {
        // Update tab buttons
        document.querySelectorAll('.tab-btn').forEach(btn => {
            btn.classList.remove('active');
        });
        document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');

        // Update tab content
        document.querySelectorAll('.tab-content').forEach(content => {
            content.classList.remove('active');
        });
        document.getElementById(`${tabName}-tab`).classList.add('active');

        // Update stats if switching to reports
        if (tabName === 'reports') {
            this.updateStats();
        }
    }

    requestOfficers() {
        this.sendNUICallback('getOfficers', {});
    }

    updateOfficersList(officers) {
        this.currentOfficers = officers;
        const officersList = document.getElementById('officersList');
        
        if (officers.length === 0) {
            officersList.innerHTML = '<div class="loading">No officers found</div>';
            return;
        }

        officersList.innerHTML = officers.map(officer => this.createOfficerCard(officer)).join('');
    }

    createOfficerCard(officer) {
        const statusClass = officer.isOnline ? 'online' : 'offline';
        const statusText = officer.isOnline ? 'Online' : 'Offline';
        
        return `
            <div class="officer-card ${statusClass}" data-citizenid="${officer.citizenid}">
                <div class="officer-header">
                    <div class="officer-name">${officer.playerName}</div>
                    <div class="officer-actions-header">
                        <div class="status-indicator ${statusClass}"></div>
                        <button class="edit-btn" data-citizenid="${officer.citizenid}" title="Edit Officer">
                            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
                                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
                            </svg>
                        </button>
                    </div>
                </div>
                <div class="officer-details">
                    <div class="detail-item">
                        <span class="detail-label">Citizen ID:</span>
                        <span class="detail-value">${officer.citizenid}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Rank:</span>
                        <span class="detail-value">${this.getRankName(officer.grade)}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Callsign:</span>
                        <span class="detail-value">${officer.callsign || 'None'}</span>
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Status:</span>
                        <span class="detail-value">${statusText}</span>
                    </div>
                </div>
            </div>
        `;
    }

    getRankName(grade) {
        const ranks = ['Recruit', 'Officer', 'Sergeant', 'Lieutenant', 'Chief'];
        return ranks[grade] || 'Unknown';
    }

    filterOfficers(searchTerm) {
        const cards = document.querySelectorAll('.officer-card');
        const term = searchTerm.toLowerCase();
        
        cards.forEach(card => {
            const officerName = card.querySelector('.officer-name').textContent.toLowerCase();
            const citizenId = card.dataset.citizenid.toLowerCase();
            const callsign = card.querySelector('.detail-value').textContent.toLowerCase();
            
            const matches = officerName.includes(term) || 
                          citizenId.includes(term) || 
                          callsign.includes(term);
            
            card.style.display = matches ? 'block' : 'none';
        });
    }

    addOfficer() {
        const formData = new FormData(document.getElementById('addOfficerForm'));
        const data = {
            sourceId: parseInt(formData.get('sourceId')),
            grade: parseInt(formData.get('officerRank')),
            callsign: formData.get('officerCallsign') || ''
        };

        this.sendNUICallback('addOfficer', data);
        document.getElementById('addOfficerForm').reset();
        this.switchTab('officers');
    }

    updateCallsign() {
        const newCallsign = document.getElementById('newCallsign').value;
        if (!newCallsign) {
            this.showNotification('Please enter a callsign', 'error');
            return;
        }

        if (newCallsign.length < this.config.minCallsignLength || 
            newCallsign.length > this.config.maxCallsignLength) {
            this.showNotification(`Callsign must be between ${this.config.minCallsignLength} and ${this.config.maxCallsignLength} characters`, 'error');
            return;
        }

        this.sendNUICallback('updateCallsign', {
            citizenid: this.currentOfficer.citizenid,
            callsign: newCallsign
        });
        
        document.getElementById('newCallsign').value = '';
    }

    updateRank() {
        const newRank = parseInt(document.getElementById('newRank').value);
        this.sendNUICallback('updateRank', {
            citizenid: this.currentOfficer.citizenid,
            grade: newRank
        });
    }

    terminateOfficer() {
        this.sendNUICallback('terminateOfficer', {
            citizenid: this.currentOfficer.citizenid
        });
        this.closeModal();
    }

    showConfirmDialog(title, message, callback) {
        document.getElementById('confirmTitle').textContent = title;
        document.getElementById('confirmMessage').textContent = message;
        
        const modal = document.getElementById('confirmModal');
        
        // Set initial state
        modal.style.display = 'flex';
        modal.style.opacity = '0';
        modal.style.visibility = 'hidden';
        
        // Force reflow
        modal.offsetHeight;
        
        // Show with animation
        requestAnimationFrame(() => {
            modal.style.opacity = '1';
            modal.style.visibility = 'visible';
            modal.classList.add('show');
        });
        
        this.confirmCallback = callback;
    }

    confirmAction() {
        if (this.confirmCallback) {
            this.confirmCallback();
        }
        this.closeConfirmModal();
    }

    closeConfirmModal() {
        const modal = document.getElementById('confirmModal');
        modal.classList.remove('show');
        
        setTimeout(() => {
            modal.style.display = 'none';
        }, 300);
        
        this.confirmCallback = null;
    }

    updateStats() {
        const totalOfficers = this.currentOfficers.length;
        const onlineOfficers = this.currentOfficers.filter(o => o.isOnline).length;
        const activeCallsigns = this.currentOfficers.filter(o => o.callsign).length;

        document.getElementById('totalOfficers').textContent = totalOfficers;
        document.getElementById('onlineOfficers').textContent = onlineOfficers;
        document.getElementById('activeCallsigns').textContent = activeCallsigns;
    }

    updateOfficerDetails(officerInfo, callsignHistory) {
        this.currentOfficer = officerInfo;
        
        // Update modal content first - get the actual player name from current officers list
        let playerName = 'Unknown';
        if (this.currentOfficers && this.currentOfficers.length > 0) {
            const officer = this.currentOfficers.find(o => o.citizenid === officerInfo.citizenid);
            if (officer) {
                playerName = officer.playerName || 'Unknown';
            }
        }
        
        document.getElementById('modalOfficerName').textContent = playerName;
        document.getElementById('modalCitizenId').textContent = officerInfo.citizenid;
        document.getElementById('modalCurrentRank').textContent = this.getRankName(officerInfo.grade);
        document.getElementById('modalCallsign').textContent = officerInfo.callsign || 'None';
        document.getElementById('modalStatus').textContent = officerInfo.status;
        
        // Show modal with proper positioning
        const modal = document.getElementById('officerModal');
        
        // Set initial state
        modal.style.display = 'flex';
        modal.style.opacity = '0';
        modal.style.visibility = 'hidden';
        
        // Force reflow
        modal.offsetHeight;
        
        // Show with animation
        requestAnimationFrame(() => {
            modal.style.opacity = '1';
            modal.style.visibility = 'visible';
            modal.classList.add('show');
        });
    }

    closeModal() {
        const modal = document.getElementById('officerModal');
        modal.classList.remove('show');
        
        // Hide modal after animation
        setTimeout(() => {
            modal.style.display = 'none';
        }, 300);
        
        this.currentOfficer = null;
    }

    showNotification(message, type = 'info') {
        // Simple notification system - you can enhance this
        console.log(`${type.toUpperCase()}: ${message}`);
    }

    sendNUICallback(callback, data) {
        fetch(`https://${GetParentResourceName()}/${callback}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(data)
        });
    }
}

// Initialize the application
const policeManagement = new PoliceManagement();

// Add click handlers for officer cards and edit buttons
document.addEventListener('click', (e) => {
    const officerCard = e.target.closest('.officer-card');
    const editBtn = e.target.closest('.edit-btn');
    
    if (officerCard && !editBtn) {
        const citizenId = officerCard.dataset.citizenid;
        policeManagement.sendNUICallback('getOfficerDetails', { citizenid: citizenId });
    }
    
    if (editBtn) {
        e.stopPropagation(); // Prevent card click
        const citizenId = editBtn.dataset.citizenid;
        policeManagement.sendNUICallback('getOfficerDetails', { citizenid: citizenId });
    }
});

// Helper function for NUI callbacks
function GetParentResourceName() {
    return 'qbx_police_management';
}
