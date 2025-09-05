# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

### Running the Server
```bash
python main.py
```
The server runs on port 80 by default and can be accessed at http://localhost

### Virtual Environment
```bash
# Activate virtual environment (Windows)
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Python Environment
This project uses Python with the following key dependencies:
- FastAPI 0.104.1 for the web framework
- uvicorn 0.15.0 for the ASGI server
- pymongo 3.12.0 for MongoDB connectivity
- schedule 1.2.1 for task scheduling

## Architecture

### Core Components

**FastAPI Web Server (`main.py`)**
- Main application entry point
- Handles user registration, member management, and trading log endpoints
- Provides web interface through Jinja2 templates
- Integrates WebSocket for real-time updates
- Runs scheduler in background thread

**Database Layer (`DB_findKorea.py`)**
- MongoDB connection and operations
- User account validation and status checks
- Trading log insertion and retrieval
- Economic indicator data access

**Data Collection (`daily_metrics.py`)**
- Collects Korean market data (KOSPI, KOSDAQ, USD/KRW)
- Scrapes economic calendar from investing.com
- Stores market metrics and economic indicators in MongoDB

**Task Scheduler (`scheduler.py`)**
- Runs daily data collection at 12:00
- Executes one-time initialization on server start

**Trading Algorithms (`.mq4` files)**
- MetaTrader 4 Expert Advisors for automated trading
- RSI-based trading strategies with martingale position sizing
- Server-side account verification integration

### MongoDB Collections
- `users` - User accounts with trading logs and deposit logs
- `economic_calendar` - Economic indicator events by date
- `market_metrics` - Daily market data (KOSPI, KOSDAQ, USD/KRW)
- `Logs` - Account balance history
- `Deposit` - Deposit transaction records

### Web Interface
Templates in `/templates/` provide:
- User registration and login
- Member management dashboard
- Trading log visualization
- Account status controls

### Data Flow
1. MQL4 algorithms check user status via `/check_User` endpoint
2. Trading results logged via `/Log` endpoint  
3. Economic indicators queried via `/check_indicator` endpoint
4. Background scheduler collects market data daily
5. Web interface provides admin controls for user management

## MongoDB Connection
The application connects to MongoDB using:
```
mongodb://admin2:asd64026@13.209.64.113:27017/?authSource=admin
```

Connection includes retry logic with 3 attempts and 5-second delays for reliability.

## Key Endpoints
- `GET /` - Main login page
- `POST /main/` - Admin authentication (password: "5555")
- `GET /check_User` - Account validation for MQL4 algorithms
- `GET /Log` - Trading log submission
- `GET /check_indicator` - Economic calendar lookup
- `POST /toggle_status/{account_number}` - Enable/disable trading
- `GET /all_members/` - Member management interface