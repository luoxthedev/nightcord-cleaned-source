/*
 * Vencord, a Discord client mod
 * Copyright (c) 2024 Vendicated and contributors
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

import "./styles.css";

import ErrorBoundary from "@components/ErrorBoundary";
import { Message } from "@vencord/discord-types";
import { findComponentByCodeLazy, findCssClassesLazy } from "@webpack";
import { React, useRef, useState } from "@webpack/common";

const CloseButton = findComponentByCodeLazy("CLOSE_BUTTON_LABEL");

function requirePaginator() { /* no-op */ }

function Paginator({ className, currentPage, maxVisiblePages, pageSize, totalCount, onPageChange }: {
    className?: string;
    currentPage: number;
    maxVisiblePages: number;
    pageSize: number;
    totalCount: number;
    onPageChange: (page: number) => void;
}) {
    const totalPages = Math.ceil(totalCount / pageSize);
    if (totalPages <= 1) return null;
    return (
        <div className={className}>
            {currentPage > 1 && <button onClick={() => onPageChange(currentPage - 1)}>←</button>}
            <span>{currentPage} / {totalPages}</span>
            {currentPage < totalPages && <button onClick={() => onPageChange(currentPage + 1)}>→</button>}
        </div>
    );
}
import { MutableRefObject } from "react";

import { jumper } from "./index";

const containerStyles = findCssClassesLazy("containerBottom", "containerTop");

export default function ReplyNavigator({ replies }: { replies: Message[]; }) {
    const [page, setPage] = useState(1);
    const [visible, setVisible] = useState(true);
    const ref: MutableRefObject<HTMLDivElement | null> = useRef(null);
    React.useEffect(() => {
        setPage(1);
        setVisible(true);
    }, [replies]);
    React.useEffect(() => {
        // https://stackoverflow.com/a/42234988
        function onMouseDown(event: MouseEvent) {
            if (ref.current && event.target instanceof Element && !ref.current.contains(event.target)) {
                setVisible(false);
            }
        }

        document.addEventListener("mousedown", onMouseDown);
        return () => {
            document.removeEventListener("mousedown", onMouseDown);
        };
    }, [ref]);
    requirePaginator();
    return (
        <ErrorBoundary>
            <div ref={ref} className={containerStyles.containerBottom + " vc-findreply-div"} style={{
                display: visible ? "flex" : "none",
            }}>
                <Paginator
                    className={"vc-findreply-paginator"}
                    currentPage={page}
                    maxVisiblePages={5}
                    pageSize={1}
                    totalCount={replies.length}
                    onPageChange={processPageChange}
                />
                <CloseButton className={"vc-findreply-close"} onClick={() => setVisible(false)} />
            </div>
        </ErrorBoundary>
    );

    function processPageChange(page: number) {
        setPage(page);
        jumper.jumpToMessage({
            channelId: replies[page - 1].channel_id,
            messageId: replies[page - 1].id,
            flash: true,
            jumpType: "INSTANT"
        });
    }
}
