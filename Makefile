.PHONY: build build-backend build-frontend test test-backend test-frontend test-frontend-critical
.PHONY: help start stop restart status logs docker-build check-deploy-env

# 复用 deploy 中的开发部署配置；.env 由 Docker Compose 解析。
DEPLOY_DIR ?= $(dir $(abspath $(lastword $(MAKEFILE_LIST))))deploy
DOCKER_COMPOSE ?= docker compose
DEV_COMPOSE = $(DOCKER_COMPOSE) --project-directory "$(DEPLOY_DIR)" --env-file "$(DEPLOY_DIR)/.env" -f "$(DEPLOY_DIR)/docker-compose.dev.yml"
WAIT_TIMEOUT ?= 180
LOG_TAIL ?= 100
SERVICE ?= sub2api
BUILD_ARGS ?=

FRONTEND_CRITICAL_VITEST := \
	src/i18n/__tests__/localeKeyCompleteness.spec.ts \
	src/api/__tests__/client.spec.ts \
	src/api/__tests__/tokenRefresh.spec.ts \
	src/api/__tests__/keys.bulkUpdate.spec.ts \
	src/components/account/__tests__/OpenAIReferralCell.spec.ts \
	src/components/account/__tests__/OpenAIReferralCell.transport.spec.ts \
	src/components/account/__tests__/OpenAIQuotaResetCell.spark_shadow.spec.ts \
	src/constants/__tests__/platforms.spec.ts \
	src/components/account/__tests__/credentialsBuilder.platformCatalog.spec.ts \
	src/components/account/__tests__/CreateAccountModal.spec.ts \
	src/components/account/__tests__/EditAccountModal.spec.ts \
	src/components/account/__tests__/credentialsBuilder.spec.ts \
	src/components/account/__tests__/OpenCodeGoProtocolRulesEditor.spec.ts \
	src/components/keys/__tests__/BulkEditKeysModal.spec.ts \
	src/components/admin/user/__tests__/UserPlatformQuotaModal.spec.ts \
	src/views/user/__tests__/KeysView.spec.ts \
	src/api/__tests__/channelMonitorV2.spec.ts \
	src/views/auth/__tests__/LinuxDoCallbackView.spec.ts \
	src/views/auth/__tests__/WechatCallbackView.spec.ts \
	src/views/user/__tests__/PaymentView.spec.ts \
	src/views/user/__tests__/PaymentResultView.spec.ts \
	src/views/user/__tests__/ChannelStatusView.mode.spec.ts \
	src/components/user/profile/__tests__/ProfileInfoCard.spec.ts \
	src/components/user/profile/__tests__/ProfileIdentityBindingsSection.spec.ts \
	src/views/admin/__tests__/SettingsView.spec.ts \
	src/features/channel-monitor-v2/__tests__/designSystem.structure.spec.ts \
	src/features/channel-monitor-v2/__tests__/monitorFormat.spec.ts \
	src/features/channel-monitor-v2/__tests__/monitorZoom.spec.ts \
	src/components/admin/channel/__tests__/PricingEntryCard.modelDefaultPrice.spec.ts

# 一键编译前后端
build: build-backend build-frontend

# 编译后端（复用 backend/Makefile）
build-backend:
	@$(MAKE) -C backend build

# 编译前端（需要已安装依赖）
build-frontend:
	@pnpm --dir frontend run build

# 运行测试（后端 + 前端）
test: test-backend test-frontend

test-backend:
	@$(MAKE) -C backend test

test-frontend:
	@pnpm --dir frontend run lint:check
	@pnpm --dir frontend run typecheck
	@$(MAKE) test-frontend-critical

test-frontend-critical:
	@pnpm --dir frontend exec vitest run $(FRONTEND_CRITICAL_VITEST)

help:
	@printf '%s\n' \
		'在项目根目录执行：' \
		'  make start          后台启动全部服务，等待健康检查通过（复用已有镜像）' \
		'  make stop           停止全部服务，保留容器、配置和数据' \
		'  make restart        重新创建全部服务并等待就绪，应用 .env 的修改' \
		'  make status         查看全部服务状态（包括已停止的容器）' \
		'  make logs           持续查看应用日志，按 Ctrl+C 退出' \
		'  make docker-build   从当前源码构建 Docker 镜像，之后执行 make start' \
		'  make build          编译前后端（原有默认任务）' \
		'  make test           运行前后端测试' \
		'' \
		'首次使用需准备 deploy/.env 并执行 make docker-build。' \
		'可选参数：WAIT_TIMEOUT=180、LOG_TAIL=100、SERVICE=sub2api、BUILD_ARGS="..."。' \
		'默认访问地址：http://localhost:8080（端口以 deploy/.env 配置为准）。'

check-deploy-env:
	@test -f "$(DEPLOY_DIR)/.env" || { \
		printf '%s\n' '缺少 deploy/.env，请复制 deploy/.env.example 并填写配置后重试。' >&2; \
		exit 1; \
	}

start: check-deploy-env
	@$(DEV_COMPOSE) up -d --no-build --pull never --wait --wait-timeout $(WAIT_TIMEOUT)
	@$(DEV_COMPOSE) ps

stop: check-deploy-env
	@$(DEV_COMPOSE) stop

# force-recreate 会重新加载 .env；普通 compose restart 不会更新环境变量。
restart: check-deploy-env
	@$(DEV_COMPOSE) up -d --no-build --pull never --force-recreate --wait --wait-timeout $(WAIT_TIMEOUT)
	@$(DEV_COMPOSE) ps

status: check-deploy-env
	@$(DEV_COMPOSE) ps -a

logs: check-deploy-env
	@$(DEV_COMPOSE) logs -f --tail=$(LOG_TAIL) $(SERVICE)

docker-build: check-deploy-env
	@$(DEV_COMPOSE) build $(BUILD_ARGS)
