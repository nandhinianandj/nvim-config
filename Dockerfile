FROM anatolelucet/neovim:latest

WORKDIR /root

# Install deps via Alpine
RUN apk add --no-cache git curl unzip ripgrep bash

# Install Python 3 + pip + pynvim
RUN apk add --no-cache python3 py3-pip bash

RUN apk add --no-cache py3-pynvim

# Add your Neovim config
RUN mkdir -p /root/.config \
    && git clone https://github.com/nandhinianandj/nvim-config /root/.config/nvim

# Ensure bash sources the apiKeys.sh if present
RUN echo '[ -f /root/.config/nvim/apiKeys.sh ] && . /root/.config/nvim/apiKeys.sh' >> /root/.bashrc

# Ensure Neovim data directory exists, then create empty viminfo
RUN mkdir -p /root/.local/share/nvim && \
    touch /root/.local/share/nvim/viminfo

# Create empty viminfo so startify doesn't complain
RUN touch /root/.local/share/nvim/viminfo

# Pre-install plugins with lazy.nvim
RUN nvim --headless "+Lazy! sync" +qa

CMD ["bash", "-lc", "nvim"]

